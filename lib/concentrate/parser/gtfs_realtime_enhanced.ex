defmodule Concentrate.Parser.GTFSRealtimeEnhanced do
  @moduledoc """
  Parser for GTFS-RT enhanced JSON files.
  """
  @behaviour Concentrate.Parser
  require Logger
  alias Concentrate.{Alert, Alert.InformedEntity, StopTimeUpdate, TripDescriptor, VehiclePosition}
  alias Concentrate.Parser.Helpers
  alias VehiclePosition.Consist, as: VehiclePositionConsist

  @default_active_period [%{"start" => nil, "end" => nil}]

  @impl Concentrate.Parser
  def parse(binary, opts) when is_binary(binary) and is_list(opts) do
    options = Helpers.parse_options(opts)

    for {:ok, json} <- [Jason.decode(binary, strings: :copy)],
        entities = decode_entities(json, options),
        decoded <- Helpers.drop_fields(entities, options.drop_fields) do
      decoded
    end
  end

  @spec decode_entities(map(), Helpers.Options.t()) :: [any()]
  defp decode_entities(%{"alerts" => alerts}, options) do
    for %{"id" => id} = alert <- alerts,
        decoded <- decode_feed_entity(%{"id" => id, "alert" => alert}, options, nil) do
      decoded
    end
  end

  defp decode_entities(%{"entity" => entities} = json, options) do
    feed_timestamp = get_in(json, ["header", "timestamp"])

    for entity <- entities,
        decoded <- decode_feed_entity(entity, options, feed_timestamp) do
      decoded
    end
  end

  @spec decode_feed_entity(map(), Helpers.Options.t(), integer | nil) :: [any()]
  defp decode_feed_entity(%{"trip_update" => %{} = trip_update}, options, _feed_timestamp) do
    decode_trip_update(trip_update, options)
  end

  defp decode_feed_entity(%{"vehicle" => %{} = vehicle}, options, feed_timestamp) do
    decode_vehicle(vehicle, options, feed_timestamp)
  end

  defp decode_feed_entity(%{"id" => id, "alert" => %{} = alert}, _options, _feed_timestamp) do
    [
      Alert.new(
        id: id,
        effect: alert_effect(Map.get(alert, "effect")),
        active_period:
          Enum.map(
            Map.get(alert, "active_period") || @default_active_period,
            &decode_active_period/1
          ),
        informed_entity:
          Enum.map(Map.get(alert, "informed_entity") || [], &decode_informed_entity/1)
      )
    ]
  end

  defp decode_feed_entity(_, _, _) do
    []
  end

  def decode_trip_update(trip_update, options) do
    td = decode_trip_descriptor(trip_update)
    decode_stop_updates(td, trip_update, options)
  end

  defp decode_stop_updates(
         td,
         %{"stop_time_update" => [update | _] = updates} = trip_update,
         options
       ) do
    max_time = options.max_time

    {arrival_time, _} = time_from_event(Map.get(update, "arrival"))
    {departure_time, _} = time_from_event(Map.get(update, "departure"))

    cond do
      td != [] and not Helpers.valid_route_id?(options, TripDescriptor.route_id(List.first(td))) ->
        []

      not Helpers.times_less_than_max?(arrival_time, departure_time, max_time) ->
        []

      true ->
        stop_updates =
          for stu <- updates do
            {arrival_time, arrival_uncertainty} = time_from_event(Map.get(stu, "arrival"))
            {departure_time, departure_uncertainty} = time_from_event(Map.get(stu, "departure"))

            StopTimeUpdate.new(
              trip_id:
                if(descriptor = Map.get(trip_update, "trip"), do: Map.get(descriptor, "trip_id")),
              stop_id: Map.get(stu, "stop_id"),
              stop_sequence: Map.get(stu, "stop_sequence"),
              schedule_relationship: schedule_relationship(Map.get(stu, "schedule_relationship")),
              arrival_time: arrival_time,
              departure_time: departure_time,
              uncertainty: arrival_uncertainty || departure_uncertainty,
              status: Map.get(stu, "boarding_status"),
              platform_id: Map.get(stu, "platform_id")
            )
          end

        td ++ stop_updates
    end
  end

  defp decode_stop_updates(td, %{"stop_time_update" => []}, options) do
    if td != [] and not Helpers.valid_route_id?(options, TripDescriptor.route_id(List.first(td))) do
      []
    else
      td
    end
  end

  @spec decode_vehicle(map(), Helpers.Options.t(), integer | nil) :: [any()]
  def decode_vehicle(vp, options, feed_timestamp) do
    position = Map.get(vp, "position", %{})
    vehicle = Map.get(vp, "vehicle", %{})
    id = Map.get(vehicle, "id")
    timestamp = Map.get(vp, "timestamp")

    Helpers.log_future_vehicle_timestamp(options, feed_timestamp, timestamp, id)

    case decode_trip_descriptor(vp) do
      [trip] ->
        if Helpers.valid_route_id?(options, TripDescriptor.route_id(trip)) do
          [
            trip,
            VehiclePosition.new(
              id: id,
              trip_id: TripDescriptor.trip_id(trip),
              stop_id: Map.get(vp, "stop_id"),
              label: Map.get(vehicle, "label"),
              license_plate: Map.get(vehicle, "license_plate"),
              latitude: Map.get(position, "latitude"),
              longitude: Map.get(position, "longitude"),
              bearing: Map.get(position, "bearing"),
              speed: Map.get(position, "speed"),
              odometer: Map.get(position, "odometer"),
              status: vehicle_status(Map.get(vp, "current_status")),
              stop_sequence: Map.get(vp, "current_stop_sequence"),
              last_updated: timestamp,
              consist: decode_consist(Map.get(vehicle, "consist")),
              occupancy_status: occupancy_status(Map.get(vp, "occupancy_status")),
              occupancy_percentage: Map.get(vp, "occupancy_percentage")
            )
          ]
        else
          []
        end

      [] ->
        []
    end
  end

  defp decode_trip_descriptor(%{"trip" => trip} = descriptor) do
    vehicle_id =
      case descriptor do
        %{"vehicle" => %{"id" => vehicle_id}} -> vehicle_id
        _ -> nil
      end

    [
      TripDescriptor.new(
        trip_id: Map.get(trip, "trip_id"),
        route_id: Map.get(trip, "route_id"),
        route_pattern_id: Map.get(trip, "route_pattern_id"),
        direction_id: Map.get(trip, "direction_id"),
        start_date: date(Map.get(trip, "start_date")),
        start_time: Map.get(trip, "start_time"),
        schedule_relationship: schedule_relationship(Map.get(trip, "schedule_relationship")),
        timestamp: Map.get(descriptor, "timestamp"),
        vehicle_id: vehicle_id
      )
    ]
  end

  defp decode_trip_descriptor(_) do
    []
  end

  defp decode_consist(nil) do
    nil
  end

  defp decode_consist(consist) do
    for c <- consist do
      VehiclePositionConsist.new(label: Map.get(c, "label"))
    end
  end

  def date(nil) do
    nil
  end

  def date(<<year_str::binary-4, month_str::binary-2, day_str::binary-2>>) do
    {
      String.to_integer(year_str),
      String.to_integer(month_str),
      String.to_integer(day_str)
    }
  end

  def date(date) when is_binary(date) do
    {:ok, date} = Date.from_iso8601(date)
    Date.to_erl(date)
  end

  defp time_from_event(nil), do: {nil, nil}
  defp time_from_event(%{"time" => time} = map), do: {time, Map.get(map, "uncertainty", nil)}

  defp schedule_relationship(nil), do: :SCHEDULED

  for relationship <- ~w(SCHEDULED ADDED UNSCHEDULED CANCELED SKIPPED NO_DATA)a do
    defp schedule_relationship(unquote(Atom.to_string(relationship))), do: unquote(relationship)
  end

  # default
  defp vehicle_status(nil), do: :IN_TRANSIT_TO

  for status <- ~w(INCOMING_AT STOPPED_AT IN_TRANSIT_TO)a do
    defp vehicle_status(unquote(Atom.to_string(status))), do: unquote(status)
  end

  defp occupancy_status(nil), do: nil

  for status <-
        ~w(EMPTY MANY_SEATS_AVAILABLE FEW_SEATS_AVAILABLE STANDING_ROOM_ONLY
           CRUSHED_STANDING_ROOM_ONLY FULL NOT_ACCEPTING_PASSENGERS)a do
    defp occupancy_status(unquote(Atom.to_string(status))), do: unquote(status)
  end

  for effect <- ~w(
        NO_SERVICE
        REDUCED_SERVICE
        SIGNIFICANT_DELAYS
        DETOUR
        ADDITIONAL_SERVICE
        MODIFIED_SERVICE
        OTHER_EFFECT
        UNKNOWN_EFFECT
        STOP_MOVED
        NO_EFFECT
        ACCESSIBILITY_ISSUE)a do
    defp alert_effect(unquote(Atom.to_string(effect))), do: unquote(effect)
  end

  defp alert_effect(other) do
    _ =
      Logger.error(fn ->
        "#{__MODULE__}: unknown alert effect #{inspect(other)}"
      end)

    :UNKNOWN_EFFECT
  end

  defp decode_active_period(map) do
    start = Map.get(map, "start") || 0

    stop =
      if stop = Map.get(map, "end") do
        stop
      else
        # 2 ^ 32 - 1
        4_294_967_295
      end

    {start, stop}
  end

  defp decode_informed_entity(map) do
    trip = Map.get(map, "trip") || %{}

    InformedEntity.new(
      trip_id: Map.get(trip, "trip_id"),
      route_id: Map.get(map, "route_id"),
      direction_id: Map.get(trip, "direction_id") || Map.get(map, "direction_id"),
      route_type: Map.get(map, "route_type"),
      stop_id: Map.get(map, "stop_id"),
      activities: Map.get(map, "activities") || []
    )
  end
end
