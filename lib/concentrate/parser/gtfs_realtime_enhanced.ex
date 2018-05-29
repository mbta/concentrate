defmodule Concentrate.Parser.GTFSRealtimeEnhanced do
  @moduledoc """
  Parser for GTFS-RT enhanced JSON files.
  """
  @behaviour Concentrate.Parser
  require Logger
  alias Concentrate.{TripUpdate, StopTimeUpdate, VehiclePosition, Alert, Alert.InformedEntity}

  @default_active_period [%{"start" => nil, "end" => nil}]

  @impl Concentrate.Parser
  def parse(binary, opts) when is_binary(binary) and is_list(opts) do
    for {:ok, json} <- [Jason.decode(binary, strings: :copy)],
        decoded <- decode_entities(json) do
      decoded
    end
  end

  defp decode_entities(%{"alerts" => alerts}) do
    for %{"id" => id} = alert <- alerts,
        decoded <- decode_feed_entity(%{"id" => id, "alert" => alert}) do
      decoded
    end
  end

  defp decode_entities(%{"entity" => entities}) do
    for entity <- entities,
        decoded <- decode_feed_entity(entity) do
      decoded
    end
  end

  defp decode_feed_entity(%{"trip_update" => trip_update}) do
    decode_trip_update(trip_update)
  end

  defp decode_feed_entity(%{"vehicle" => vehicle}) do
    decode_vehicle(vehicle)
  end

  defp decode_feed_entity(%{"id" => id, "alert" => alert}) do
    [
      Alert.new(
        id: id,
        effect: alert_effect(alert["effect"]),
        active_period:
          Enum.map(alert["active_period"] || @default_active_period, &decode_active_period/1),
        informed_entity: Enum.map(alert["informed_entity"] || [], &decode_informed_entity/1)
      )
    ]
  end

  defp decode_feed_entity(_) do
    []
  end

  def decode_trip_update(trip_update) do
    tu = decode_trip_descriptor(trip_update["trip"])

    stop_updates =
      for stu <- trip_update["stop_time_update"] do
        StopTimeUpdate.new(
          trip_id: if(trip_update["trip"], do: trip_update["trip"]["trip_id"]),
          stop_id: stu["stop_id"],
          stop_sequence: stu["stop_sequence"],
          schedule_relationship: schedule_relationship(stu["schedule_relationship"]),
          arrival_time: time_from_event(stu["arrival"]),
          departure_time: time_from_event(stu["departure"]),
          status: boarding_status(stu["boarding_status"]),
          platform_id: stu["platform_id"]
        )
      end

    tu ++ stop_updates
  end

  def decode_vehicle(vp) do
    position = Map.get(vp, "position", %{})
    vehicle = Map.get(vp, "vehicle", %{})

    case decode_trip_descriptor(Map.get(vp, "trip")) do
      [trip] ->
        [
          trip,
          VehiclePosition.new(
            id: Map.get(vehicle, "id"),
            trip_id: TripUpdate.trip_id(trip),
            stop_id: Map.get(vp, "stop_id"),
            label: Map.get(vehicle, "label"),
            license_plate: Map.get(vehicle, "license_plate"),
            latitude: Map.get(position, "latitude"),
            longitude: Map.get(position, "longitude"),
            bearing: Map.get(position, "bearing"),
            speed: Map.get(position, "speed"),
            odometer: Map.get(position, "odometer"),
            status: Map.get(vp, "current_status"),
            stop_sequence: Map.get(vp, "current_stop_sequence"),
            last_updated: Map.get(vp, "timestamp")
          )
        ]

      [] ->
        []
    end
  end

  defp decode_trip_descriptor(nil) do
    []
  end

  defp decode_trip_descriptor(trip) do
    [
      TripUpdate.new(
        trip_id: trip["trip_id"],
        route_id: trip["route_id"],
        direction_id: trip["direction_id"],
        start_date: date(trip["start_date"]),
        start_time: trip["start_time"],
        schedule_relationship: schedule_relationship(trip["schedule_relationship"])
      )
    ]
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

  defp time_from_event(nil), do: nil
  defp time_from_event(%{"time" => time}), do: time

  defp schedule_relationship(nil), do: :SCHEDULED

  for relationship <- ~w(SCHEDULED ADDED UNSCHEDULED CANCELED SKIPPED NO_DATA)a do
    defp schedule_relationship(unquote(Atom.to_string(relationship))), do: unquote(relationship)
  end

  defp boarding_status(nil), do: nil

  for status <- ~w(
        ON_TIME DELAYED ARRIVING NOW_BOARDING ALL_ABOARD DEPARTED
        LATE BUS_SUBSTITUTION CANCELLED SEE_AGENT NOT_STOPPING_HERE
        ARRIVED INFO_TO_FOLLOW)a do
    defp boarding_status(unquote(Atom.to_string(status))), do: unquote(status)
  end

  defp boarding_status(unknown) do
    Logger.error(fn ->
      "#{__MODULE__}: unknown boarding status #{inspect(unknown)}"
    end)

    nil
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
        STOP_MOVED)a do
    defp alert_effect(unquote(Atom.to_string(effect))), do: unquote(effect)
  end

  defp alert_effect(other) do
    Logger.error(fn ->
      "#{__MODULE__}: unknown alert effect #{inspect(other)}"
    end)

    :UNKNOWN_EFFECT
  end

  defp decode_active_period(map) do
    start = map["start"] || 0

    stop =
      if stop = map["end"] do
        stop
      else
        # 2 ^ 32 - 1
        4_294_967_295
      end

    {start, stop}
  end

  defp decode_informed_entity(map) do
    trip = map["trip"] || %{}

    InformedEntity.new(
      trip_id: trip["trip_id"],
      route_id: map["route_id"],
      direction_id: trip["direction_id"] || map["direction_id"],
      route_type: map["route_type"],
      stop_id: map["stop_id"],
      activities: map["activities"] || []
    )
  end
end
