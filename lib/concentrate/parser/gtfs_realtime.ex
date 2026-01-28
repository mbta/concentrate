defmodule Concentrate.Parser.GTFSRealtime do
  @moduledoc """
  Parser for [GTFS-Realtime](https://developers.google.com/transit/gtfs-realtime/) ProtoBuf files.
  """
  @behaviour Concentrate.Parser
  alias Concentrate.Parser.Helpers
  require Logger

  alias Concentrate.{
    Alert,
    Alert.InformedEntity,
    FeedUpdate,
    StopTimeUpdate,
    TripDescriptor,
    VehiclePosition
  }

  @impl Concentrate.Parser
  def parse(binary, opts) when is_binary(binary) and is_list(opts) do
    options = Helpers.parse_options(opts)
    message = :gtfs_realtime_proto.decode_msg(binary, :FeedMessage, [])

    feed_timestamp = message.header.timestamp
    partial? = message.header.incrementality == :DIFFERENTIAL

    updates =
      message.entity
      |> Enum.flat_map(&decode_feed_entity(&1, options, feed_timestamp))
      |> Helpers.drop_fields(options.drop_fields)

    FeedUpdate.new(
      updates: updates,
      url: Keyword.get(opts, :feed_url),
      timestamp: feed_timestamp,
      partial?: partial?
    )
  end

  @spec decode_feed_entity(map(), Helpers.Options.t(), integer | nil) :: [any()]
  def decode_feed_entity(entity, options, feed_timestamp) do
    vp = decode_vehicle(Map.get(entity, :vehicle), options, feed_timestamp)
    stop_updates = decode_trip_update(Map.get(entity, :trip_update), options)
    alerts = decode_alert(entity)
    List.flatten([alerts, vp, stop_updates])
  end

  @spec decode_vehicle(map() | nil, Helpers.Options.t(), integer | nil) :: [any()]
  def decode_vehicle(nil, _opts, _feed_timestamp) do
    []
  end

  def decode_vehicle(vp, options, feed_timestamp) do
    td = decode_trip_descriptor(vp)
    decode_vehicle_position(td, vp, options, feed_timestamp)
  end

  @spec decode_vehicle_position(
          [TripDescriptor.t()],
          map(),
          Helpers.Options.t(),
          integer | nil
        ) :: [any()]
  defp decode_vehicle_position(td, vp, options, feed_timestamp) do
    if td == [] or Helpers.valid_route_id?(options, TripDescriptor.route_id(List.first(td))) do
      trip_id =
        case vp do
          %{trip: %{trip_id: id}} -> id
          _ -> nil
        end

      vehicle = vp.vehicle
      position = vp.position
      id = Map.get(vehicle, :id)
      timestamp = Map.get(vp, :timestamp)

      Helpers.log_future_vehicle_timestamp(options, feed_timestamp, timestamp, id)

      td ++
        [
          VehiclePosition.new(
            id: id,
            trip_id: trip_id,
            stop_id: Map.get(vp, :stop_id),
            label: Map.get(vehicle, :label),
            license_plate: Map.get(vehicle, :license_plate),
            latitude: Map.get(position, :latitude),
            longitude: Map.get(position, :longitude),
            bearing: Map.get(position, :bearing),
            speed: Map.get(position, :speed),
            odometer: Map.get(position, :odometer),
            status: Map.get(vp, :current_status),
            stop_sequence: Map.get(vp, :current_stop_sequence),
            last_updated: timestamp,
            occupancy_status: Map.get(vp, :occupancy_status),
            occupancy_percentage: Map.get(vp, :occupancy_percentage),
            multi_carriage_details:
              VehiclePosition.CarriageDetails.build_multi_carriage_details(
                Helpers.parse_multi_carriage_details(vp)
              )
          )
        ]
    else
      []
    end
  end

  @spec decode_trip_update(map() | nil, Helpers.Options.t()) :: [any()]
  def decode_trip_update(nil, _options) do
    []
  end

  def decode_trip_update(trip_update, options) do
    td = decode_trip_descriptor(trip_update)
    decode_stop_updates(td, trip_update, options)
  end

  defp decode_stop_updates(td, %{stop_time_update: [update | _] = updates} = trip_update, options) do
    max_time = options.max_time

    {arrival_time, _} = time_from_event(Map.get(update, :arrival))
    {departure_time, _} = time_from_event(Map.get(update, :departure))

    cond do
      td != [] and not Helpers.valid_route_id?(options, TripDescriptor.route_id(List.first(td))) ->
        []

      not Helpers.times_less_than_max?(arrival_time, departure_time, max_time) ->
        []

      true ->
        stop_updates =
          for stu <- updates do
            {arrival_time, arrival_uncertainty} = time_from_event(Map.get(stu, :arrival))
            {departure_time, departure_uncertainty} = time_from_event(Map.get(stu, :departure))

            StopTimeUpdate.new(
              trip_id: Map.get(trip_update.trip, :trip_id),
              stop_id: Map.get(stu, :stop_id),
              stop_sequence: Map.get(stu, :stop_sequence),
              schedule_relationship: Map.get(stu, :schedule_relationship, :SCHEDULED),
              arrival_time: arrival_time,
              departure_time: departure_time,
              uncertainty: arrival_uncertainty || departure_uncertainty
            )
          end

        td ++ stop_updates
    end
  end

  defp decode_stop_updates(td, %{stop_time_update: []}, options) do
    if td != [] and not Helpers.valid_route_id?(options, TripDescriptor.route_id(List.first(td))) do
      []
    else
      td
    end
  end

  @spec decode_trip_descriptor(map()) :: [TripDescriptor.t()]
  defp decode_trip_descriptor(%{trip: trip} = descriptor) do
    [
      TripDescriptor.new(
        trip_id: Map.get(trip, :trip_id),
        route_id: Map.get(trip, :route_id),
        direction_id: Map.get(trip, :direction_id),
        start_date: date(Map.get(trip, :start_date)),
        start_time: time(Map.get(trip, :start_time)),
        schedule_relationship: Map.get(trip, :schedule_relationship, :SCHEDULED),
        vehicle_id: decode_trip_descriptor_vehicle_id(descriptor),
        timestamp: decode_trip_descriptor_timestamp(descriptor)
      )
    ]
  end

  defp decode_trip_descriptor(_) do
    []
  end

  defp decode_trip_descriptor_vehicle_id(%{vehicle: %{id: vehicle_id}}), do: vehicle_id
  defp decode_trip_descriptor_vehicle_id(_), do: nil

  defp decode_trip_descriptor_timestamp(%{timestamp: timestamp}), do: timestamp
  defp decode_trip_descriptor_timestamp(_), do: nil

  defp date(nil) do
    nil
  end

  defp date(<<year_str::binary-4, month_str::binary-2, day_str::binary-2>>) do
    {
      String.to_integer(year_str),
      String.to_integer(month_str),
      String.to_integer(day_str)
    }
  end

  defp time(nil) do
    nil
  end

  defp time(<<_hour::binary-2, ":", _minute::binary-2, ":", _second::binary-2>> = bin) do
    bin
  end

  defp time(<<_hour::binary-1, ":", _minute::binary-2, ":", _second::binary-2>> = bin) do
    "0" <> bin
  end

  defp time(bin) when is_binary(bin) do
    # invalid time, treat as missing
    nil
  end

  defp decode_alert(%{id: "691539" = id, alert: %{} = alert}) do
    added_informed_entities = [
      InformedEntity.new(%{
        #    facility_id: "park-DB-2205",
        stop_id: "DB-2205-B0",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-DB-2258",
        stop_id: "DB-2258-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-ER-0168-garage",
        stop_id: "37150",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-ER-0183-garage",
        stop_id: "ER-0183-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-ER-0183-garage",
        stop_id: "ER-0183-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-ER-0312",
        stop_id: "ER-0312-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FB-0148",
        stop_id: "FB-0148-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FB-0230",
        stop_id: "FB-0230-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FB-0275",
        stop_id: "FB-0275-B1",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0064-royal",
        stop_id: "FR-0064-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0064-royal",
        stop_id: "FR-0064-B0",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0115",
        stop_id: "FR-0115-B0",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0253",
        stop_id: "FR-0253-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0394",
        stop_id: "FR-0394-B1",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0494-garage",
        stop_id: "FR-0494-CS",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-GB-0198",
        stop_id: "GB-0198-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-GB-0229",
        stop_id: "GB-0229-B1",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-GB-0254",
        stop_id: "Manchester-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-GRB-0162",
        stop_id: "GRB-0162-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-GRB-0183",
        stop_id: "GRB-0183-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-GRB-0233",
        stop_id: "GRB-0233-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-KB-0351",
        stop_id: "KB-0351-B1",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NB-0080",
        stop_id: "NB-0080-B2",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NB-0109",
        stop_id: "NB-0109-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NB-0127",
        stop_id: "NB-0127-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NBM-0374",
        stop_id: "NBM-0374-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NEC-1969",
        stop_id: "NEC-1969-B",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NEC-2040",
        stop_id: "NEC-2040-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NHRML-0218-station",
        stop_id: "NHRML-0218-B1",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NHRML-0218-station",
        stop_id: "NHRML-0218-B2",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-PB-0245",
        stop_id: "PB-0245-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WML-0125",
        stop_id: "WML-0125-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WML-0135",
        stop_id: "WML-0135-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0067",
        stop_id: "WR-0067-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0075",
        stop_id: "WR-0075-B1",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0099",
        stop_id: "WR-0099-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0163",
        stop_id: "WR-0163-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0228",
        stop_id: "WR-0228-B0",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0325",
        stop_id: "WR-0325-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-butlr",
        stop_id: "70265",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-butlr",
        stop_id: "70266",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-mlmnl",
        stop_id: "5327",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-mlmnl",
        stop_id: "WR-0045-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-north-garage",
        stop_id: "BNT-0000-04",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-north-garage",
        stop_id: "BNT-0000-05",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-north-garage",
        stop_id: "BNT-0000-10",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-nqncy-garage",
        stop_id: "70098",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-ogmnl",
        stop_id: "Oak Grove-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-sstat-garage",
        stop_id: "NEC-2287-11",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-sull",
        stop_id: "29006",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0064-claflin",
        stop_id: "FR-0064-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0064-claflin",
        stop_id: "FR-0064-B0",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NHRML-0078-aberjona",
        stop_id: "NHRML-0078-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NHRML-0078-aberjona",
        stop_id: "NHRML-0078-B",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-qamnl-garage",
        stop_id: "41031",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-sull",
        stop_id: "70030",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-waban",
        stop_id: "70165",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-welln-lot",
        stop_id: "52710",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-wlsta",
        stop_id: "70100",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-wondl-nshore",
        stop_id: "15796",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-wondl-nshore",
        stop_id: "15798",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-welln-garage",
        stop_id: "52715",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-welln-garage",
        stop_id: "52716",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-welln-garage",
        stop_id: "70032",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-wondl-garage",
        stop_id: "70059",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-DB-0095",
        stop_id: "DB-0095-B0",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-DB-0095",
        stop_id: "NEC-2192-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-DB-2258",
        stop_id: "DB-2258-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-DB-2258",
        stop_id: "DB-2258-B0",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-DB-2258",
        stop_id: "DB-2258-B1",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-ER-0168-garage",
        stop_id: "ER-0168-B",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-ER-0208",
        stop_id: "ER-0208-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-ER-0208",
        stop_id: "ER-0208-B",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FB-0109",
        stop_id: "FB-0109-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FB-0230",
        stop_id: "FB-0230-B",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0137",
        stop_id: "FR-0137-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0219",
        stop_id: "FR-0219-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0361-garage",
        stop_id: "FR-0361-B1",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0394",
        stop_id: "FR-0394-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-GB-0198",
        stop_id: "GB-0198-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-GB-0198",
        stop_id: "GB-0198-B3",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-GB-0229",
        stop_id: "GB-0229-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-GB-0254",
        stop_id: "GB-0254-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-GB-0316",
        stop_id: "GB-0316-B0",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NB-0064",
        stop_id: "NB-0064-B0",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NB-0072",
        stop_id: "NB-0072-B0",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NB-0080",
        stop_id: "NB-0080-B0",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NB-0109",
        stop_id: "NB-0109-B0",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NB-0120",
        stop_id: "91852",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NB-0127",
        stop_id: "NB-0127-B0",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NB-0137",
        stop_id: "NB-0137-B1",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NBM-0523",
        stop_id: "NBM-0523-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NEC-1659-garage",
        stop_id: "NEC-1659-B",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NEC-1851-garage",
        stop_id: "NEC-1851-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NEC-1919",
        stop_id: "NEC-1919-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NHRML-0127-parkride",
        stop_id: "NHRML-0127-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NHRML-0127-parkride",
        stop_id: "NHRML-0127-B",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NHRML-0218-station",
        stop_id: "NHRML-0218-B0",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-PB-0281",
        stop_id: "PB-0281-B0",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WML-0102",
        stop_id: "WML-0102-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WML-0147",
        stop_id: "WML-0147-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WML-0199",
        stop_id: "WML-0199-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0062",
        stop_id: "WR-0062-B1",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0075",
        stop_id: "WR-0075-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0085",
        stop_id: "WR-0085-B1",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0329",
        stop_id: "WR-0329-B",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-alfcl-garage",
        stop_id: "14112",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-alfcl-garage",
        stop_id: "14118",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-alfcl-garage",
        stop_id: "9070061",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-forhl",
        stop_id: "NEC-2237-05",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-matt",
        stop_id: "70275",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-miltt",
        stop_id: "70267",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-mlmnl",
        stop_id: "53270",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-mlmnl",
        stop_id: "70034",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-mlmnl",
        stop_id: "70035",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-north-garage",
        stop_id: "70026",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-north-garage",
        stop_id: "70027",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-north-garage",
        stop_id: "BNT-0000-08",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-qamnl-lot",
        stop_id: "70104",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-sdmnl",
        stop_id: "70054",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-sstat-garage",
        stop_id: "NEC-2287",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-sstat-garage",
        stop_id: "NEC-2287-04",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-sstat-garage",
        stop_id: "NEC-2287-06",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-sull",
        stop_id: "29003",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-sull",
        stop_id: "29005",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-sull",
        stop_id: "29007",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0098-carter",
        stop_id: "FR-0098-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-MM-0200-garage",
        stop_id: "MM-0200-CS",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NHRML-0127-airport",
        stop_id: "NHRML-0127-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NHRML-0127-airport",
        stop_id: "NHRML-0127-B",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-sull",
        stop_id: "29011",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-sull",
        stop_id: "29012",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-wondl-nshore",
        stop_id: "70060",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-woodl-garage",
        stop_id: "70163",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-welln-garage",
        stop_id: "52712",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-welln-garage",
        stop_id: "52714",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-DB-0095",
        stop_id: "NEC-2192-03",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-ER-0115-garage",
        stop_id: "ER-0115-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-ER-0362",
        stop_id: "ER-0362-B",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0064-royal",
        stop_id: "FR-0064-B1",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0098-railroad",
        stop_id: "FR-0098-B0",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0098-railroad",
        stop_id: "FR-0098-B1",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0253",
        stop_id: "FR-0253-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0361-garage",
        stop_id: "FR-0361-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FRS-0109",
        stop_id: "FRS-0109-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-GB-0254",
        stop_id: "GB-0254-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-GB-0296",
        stop_id: "GB-0296-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-GRB-0276",
        stop_id: "GRB-0276-B",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-MM-0186",
        stop_id: "39870",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NB-0064",
        stop_id: "NB-0064-B1",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NB-0076",
        stop_id: "NB-0076-B0",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NB-0120",
        stop_id: "NB-0120-B0",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NEC-1851-garage",
        stop_id: "NEC-1851-05",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NEC-2040",
        stop_id: "NEC-2040-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NEC-2173-garage",
        stop_id: "NEC-2173-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NHRML-0127-parkride",
        stop_id: "NHRML-0127-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NHRML-0152",
        stop_id: "NHRML-0152-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-PB-0212",
        stop_id: "PB-0212-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-PB-0356",
        stop_id: "PB-0356-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WML-0125",
        stop_id: "WML-0125-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WML-0135",
        stop_id: "WML-0135-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WML-0252",
        stop_id: "WML-0252-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0062",
        stop_id: "WR-0062-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0062",
        stop_id: "WR-0062-B3",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0099",
        stop_id: "WR-0099-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0120",
        stop_id: "WR-0120-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0205",
        stop_id: "WR-0205-B2",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0228",
        stop_id: "WR-0228-B1",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-alfcl-garage",
        stop_id: "14120",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-alfcl-garage",
        stop_id: "14122",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-bcnfd",
        stop_id: "70176",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-brkhl",
        stop_id: "70179",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-chhil",
        stop_id: "70172",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-eliot",
        stop_id: "70166",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-forhl",
        stop_id: "10642",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-mlmnl",
        stop_id: "5072",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-north-garage",
        stop_id: "70206",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-nqncy-garage",
        stop_id: "3125",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-orhte",
        stop_id: "5879",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-shmnl",
        stop_id: "70087",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-sstat-garage",
        stop_id: "NEC-2287-12",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0064-claflin",
        stop_id: "FR-0064-B1",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0098-carter",
        stop_id: "FR-0098-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NHRML-0127-airport",
        stop_id: "NHRML-0127-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NHRML-0218-eastern",
        stop_id: "NHRML-0218-B0",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WML-0442-garage",
        stop_id: "WML-0442-CS",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-sull",
        stop_id: "29008",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-welln-lot",
        stop_id: "52711",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-welln-lot",
        stop_id: "52720",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-woodl-garage",
        stop_id: "70162",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-wondl-garage",
        stop_id: "15799",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-wondl-garage",
        stop_id: "15800",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-DB-0095",
        stop_id: "FB-0095-05",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-DB-2205",
        stop_id: "DB-2205-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-ER-0128",
        stop_id: "ER-0128-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-ER-0208",
        stop_id: "ER-0208-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-ER-0227",
        stop_id: "ER-0227-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-ER-0362",
        stop_id: "ER-0362-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FB-0275",
        stop_id: "FB-0275-B0",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FB-0303",
        stop_id: "FB-0303-B",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0098-railroad",
        stop_id: "FR-0098-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0115",
        stop_id: "FR-0115-B1",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0137",
        stop_id: "FR-0137-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0201",
        stop_id: "FR-0201-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0219",
        stop_id: "FR-0219-B",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FS-0049",
        stop_id: "FS-0049-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-GB-0229",
        stop_id: "GB-0229-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-GB-0316",
        stop_id: "GB-0316-B1",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-GRB-0233",
        stop_id: "GRB-0233-B",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-GRB-0276",
        stop_id: "GRB-0276-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NB-0064",
        stop_id: "NB-0064-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NB-0072",
        stop_id: "NB-0072-B",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NB-0080",
        stop_id: "NB-0080-B1",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NB-0127",
        stop_id: "NB-0127-B1",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NEC-1891-lot",
        stop_id: "NEC-1891-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NEC-1969",
        stop_id: "NEC-1969-04",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NEC-2108",
        stop_id: "NEC-2108-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NEC-2139",
        stop_id: "NEC-2139",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NEC-2139",
        stop_id: "NEC-2139-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NEC-2139",
        stop_id: "NEC-2139-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NEC-2139",
        stop_id: "SB-0150-04",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NEC-2203",
        stop_id: "NEC-2203-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NHRML-0055",
        stop_id: "6303",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NHRML-0055",
        stop_id: "NHRML-0055-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NHRML-0073",
        stop_id: "NHRML-0073-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NHRML-0073",
        stop_id: "NHRML-0073-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NHRML-0078-waterfield",
        stop_id: "NHRML-0078-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NHRML-0218-station",
        stop_id: "NHRML-0218-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-PB-0194",
        stop_id: "PB-0194-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-SB-0189",
        stop_id: "SB-0189-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WML-0214",
        stop_id: "WML-0214-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WML-0252",
        stop_id: "WML-0252-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WML-0442-lot",
        stop_id: "WML-0442-CS",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0067",
        stop_id: "WR-0067-B1",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0205",
        stop_id: "WR-0205-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0228",
        stop_id: "WR-0228-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0264",
        stop_id: "WR-0264-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0325",
        stop_id: "WR-0325-B",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0329",
        stop_id: "WR-0329-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-brntn-lot-a",
        stop_id: "MM-0109-CS",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-chhil",
        stop_id: "70173",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-forhl",
        stop_id: "NEC-2237-03",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-miltt",
        stop_id: "70268",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-north-garage",
        stop_id: "BNT-0000-03",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-north-garage",
        stop_id: "BNT-0000-B1",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-nqncy-garage",
        stop_id: "70097",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-ogmnl",
        stop_id: "9328",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-orhte",
        stop_id: "70051",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-river",
        stop_id: "70160",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-sdmnl",
        stop_id: "70053",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-sull",
        stop_id: "29001",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-ER-0117-ellis",
        stop_id: "ER-0117-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-brntn-garage",
        stop_id: "MM-0109-CS",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-qamnl-garage",
        stop_id: "70104",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-sull",
        stop_id: "29010",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-sull",
        stop_id: "70031",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-welln-lot",
        stop_id: "52712",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-welln-lot",
        stop_id: "52714",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-wlsta",
        stop_id: "70099",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-wondl-nshore",
        stop_id: "70059",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-wondl-garage",
        stop_id: "15796",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-wondl-garage",
        stop_id: "15798",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-ER-0208",
        stop_id: "ER-0208-B1",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-ER-0276",
        stop_id: "ER-0276-B",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FB-0109",
        stop_id: "FB-0109-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FB-0118",
        stop_id: "FB-0118-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FB-0148",
        stop_id: "Norwood Central-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0132",
        stop_id: "FR-0132-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0167",
        stop_id: "FR-0167-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0253",
        stop_id: "FR-0253-B",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0301",
        stop_id: "FR-0301-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0301",
        stop_id: "FR-0301-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0394",
        stop_id: "FR-0394-B0",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0451-garage",
        stop_id: "FR-0451-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-3338-garage",
        stop_id: "FR-3338-CS",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-GB-0316",
        stop_id: "GB-0316-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-GRB-0118",
        stop_id: "GRB-0118-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-GRB-0146",
        stop_id: "GRB-0146-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-MM-0150",
        stop_id: "MM-0150-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-MM-0186",
        stop_id: "MM-0186-CS",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-MM-0200-lot",
        stop_id: "MM-0200-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NB-0120",
        stop_id: "NB-0120-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NB-0127",
        stop_id: "NB-0127-B",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NB-0137",
        stop_id: "NB-0137-B",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NB-0137",
        stop_id: "NB-0137-B0",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NBM-0374",
        stop_id: "NBM-0374",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NEC-1659-garage",
        stop_id: "NEC-1659-03",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NEC-1969",
        stop_id: "NEC-1969-03",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NEC-2203",
        stop_id: "NEC-2203-03",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NHRML-0055",
        stop_id: "6316",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NHRML-0055",
        stop_id: "NHRML-0055-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NHRML-0073",
        stop_id: "NHRML-0073-B",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NHRML-0078-waterfield",
        stop_id: "NHRML-0078-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NHRML-0078-waterfield",
        stop_id: "NHRML-0078-B",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WML-0177",
        stop_id: "WML-0177-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WML-0199",
        stop_id: "WML-0199-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WML-0274",
        stop_id: "WML-0274-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WML-0340",
        stop_id: "WML-0340-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WML-0340",
        stop_id: "WML-0340-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0067",
        stop_id: "WR-0067-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0085",
        stop_id: "WR-0085-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0120",
        stop_id: "WR-0120-B",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0163",
        stop_id: "WR-0163-B0",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0205",
        stop_id: "WR-0205-B0",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-alfcl-garage",
        stop_id: "70061",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-alfcl-garage",
        stop_id: "Alewife-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-bcnfd",
        stop_id: "70177",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-bmmnl",
        stop_id: "70056",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-brkhl",
        stop_id: "70178",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-brntn-lot-a",
        stop_id: "38671",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-eliot",
        stop_id: "70167",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-matt",
        stop_id: "18511",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-north-garage",
        stop_id: "BNT-0000",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-ogmnl",
        stop_id: "70036",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-ogmnl",
        stop_id: "WR-0053-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-orhte",
        stop_id: "5880",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-qamnl-lot",
        stop_id: "70103",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-river",
        stop_id: "38155",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-sstat-garage",
        stop_id: "NEC-2287-08",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-sstat-garage",
        stop_id: "NEC-2287-10",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-sstat-garage",
        stop_id: "NEC-2287-13",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NHRML-0218-eastern",
        stop_id: "NHRML-0218-B1",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NHRML-0218-eastern",
        stop_id: "NHRML-0218-B2",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WML-0091-newton",
        stop_id: "WML-0091-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-brntn-garage",
        stop_id: "38671",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-waban",
        stop_id: "70164",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-welln-lot",
        stop_id: "70033",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-wondl-nshore",
        stop_id: "15797",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-welln-garage",
        stop_id: "52713",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-DB-0095",
        stop_id: "FB-0095-04",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-DB-2205",
        stop_id: "DB-2205-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-ER-0117-garage",
        stop_id: "ER-0117-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-ER-0128",
        stop_id: "ER-0128-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-ER-0128",
        stop_id: "ER-0128-B1",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-ER-0168-garage",
        stop_id: "ER-0168-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-ER-0183-garage",
        stop_id: "ER-0183-B",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-ER-0227",
        stop_id: "ER-0227-B0",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-ER-0312",
        stop_id: "ER-0312-B",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FB-0148",
        stop_id: "FB-0148-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FB-0191",
        stop_id: "FB-0191-B",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FB-0275",
        stop_id: "FB-0275-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0394",
        stop_id: "FR-0394-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0451-garage",
        stop_id: "FR-0451-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-GB-0296",
        stop_id: "GB-0296-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-GB-0353",
        stop_id: "GB-0353-B",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-KB-0351",
        stop_id: "KB-0351-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-MM-0150",
        stop_id: "4255",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-MM-0186",
        stop_id: "MM-0186-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-MM-0200-lot",
        stop_id: "MM-0200-CS",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-MM-0219",
        stop_id: "MM-0219-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-MM-0356",
        stop_id: "MM-0356-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NB-0076",
        stop_id: "NB-0076-B1",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NBM-0374",
        stop_id: "NBM-0374-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NBM-0546",
        stop_id: "NBM-0546-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NEC-1768-garage",
        stop_id: "NEC-1768-03",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NEC-1851-garage",
        stop_id: "NEC-1851-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NEC-1891-lot",
        stop_id: "NEC-1891-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NEC-1891-lot",
        stop_id: "NEC-1891-B",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NEC-2108",
        stop_id: "NEC-2108-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NHRML-0152",
        stop_id: "NHRML-0152-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NHRML-0218-station",
        stop_id: "NHRML-0218-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NHRML-0254-garage",
        stop_id: "NHRML-0254-04",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-PB-0158",
        stop_id: "PB-0158-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-PB-0158",
        stop_id: "South Weymouth-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WML-0177",
        stop_id: "WML-0177-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WML-0214",
        stop_id: "WML-0214-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WML-0274",
        stop_id: "WML-0274-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WML-0364",
        stop_id: "WML-0364-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0075",
        stop_id: "WR-0075-B0",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0085",
        stop_id: "WR-0085-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0264",
        stop_id: "WR-0264-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0329",
        stop_id: "WR-0329-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-alfcl-garage",
        stop_id: "14123",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-brntn-lot-a",
        stop_id: "MM-0109-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-forhl",
        stop_id: "70001",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-forhl",
        stop_id: "875",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-matt",
        stop_id: "185",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-matt",
        stop_id: "70276",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-north-garage",
        stop_id: "BNT-0000-07",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-north-garage",
        stop_id: "BNT-0000-09",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-orhte",
        stop_id: "15880",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-qamnl-lot",
        stop_id: "41031",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-sstat-garage",
        stop_id: "70079",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-sstat-garage",
        stop_id: "84611",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-sull",
        stop_id: "29002",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-brntn-garage",
        stop_id: "MM-0109-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-sull",
        stop_id: "29009",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-welln-lot",
        stop_id: "52715",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-welln-lot",
        stop_id: "52716",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-welln-lot",
        stop_id: "70032",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-welln-garage",
        stop_id: "52710",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-wondl-garage",
        stop_id: "70060",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-DB-2205",
        stop_id: "DB-2205-B1",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-ER-0115-garage",
        stop_id: "14748",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-ER-0362",
        stop_id: "ER-0362-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FB-0143",
        stop_id: "FB-0143-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FB-0303",
        stop_id: "FB-0303-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0064-royal",
        stop_id: "FR-0064-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0115",
        stop_id: "FR-0115-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0132",
        stop_id: "FR-0132-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0201",
        stop_id: "FR-0201-B0",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0301",
        stop_id: "FR-0301-B",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0494-garage",
        stop_id: "FR-0494-B",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-3338-garage",
        stop_id: "FR-3338-B",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FRS-0054",
        stop_id: "FRS-0054-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FS-0049",
        stop_id: "FS-0049-B",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-GB-0254",
        stop_id: "GB-0254-B2",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-GB-0296",
        stop_id: "GB-0296-B2",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-GB-0353",
        stop_id: "GB-0353-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-GRB-0199",
        stop_id: "GRB-0199-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NB-0076",
        stop_id: "NB-0076-B",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NB-0076",
        stop_id: "NB-0076-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NB-0080",
        stop_id: "NB-0080-B3",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NB-0080",
        stop_id: "NB-0080-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NB-0109",
        stop_id: "NB-0109-B1",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NB-0120",
        stop_id: "NB-0120-B1",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NB-0137",
        stop_id: "NB-0137-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NEC-1851-garage",
        stop_id: "NEC-1851-03",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NEC-1851-garage",
        stop_id: "NEC-1851-B0",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NEC-1919",
        stop_id: "NEC-1919-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NEC-2173-garage",
        stop_id: "NEC-2173-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NHRML-0254-garage",
        stop_id: "NHRML-0254-03",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-PB-0281",
        stop_id: "PB-0281-CS",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WML-0147",
        stop_id: "WML-0147-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WML-0214",
        stop_id: "WML-0214-B",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WML-0252",
        stop_id: "WML-0252-B",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WML-0364",
        stop_id: "WML-0364-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0062",
        stop_id: "WR-0062-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0062",
        stop_id: "WR-0062-B2",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0075",
        stop_id: "WR-0075-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0075",
        stop_id: "WR-0075-B2",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0085",
        stop_id: "WR-0085-B0",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0099",
        stop_id: "WR-0099-B0",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0099",
        stop_id: "WR-0099-B1",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-bmmnl",
        stop_id: "70055",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-brntn-lot-a",
        stop_id: "70105",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-brntn-lot-a",
        stop_id: "Braintree-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-forhl",
        stop_id: "Forest Hills-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-longw",
        stop_id: "70182",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-north-garage",
        stop_id: "BNT-0000-B2",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-orhte",
        stop_id: "70052",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-sstat-garage",
        stop_id: "70080",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-sstat-garage",
        stop_id: "NEC-2287-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-sstat-garage",
        stop_id: "NEC-2287-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-sstat-garage",
        stop_id: "NEC-2287-03",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-sstat-garage",
        stop_id: "NEC-2287-05",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-sstat-garage",
        stop_id: "NEC-2287-B",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-ER-0117-ellis",
        stop_id: "ER-0117-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0064-claflin",
        stop_id: "FR-0064-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NHRML-0218-eastern",
        stop_id: "NHRML-0218-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-brntn-garage",
        stop_id: "70105",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-brntn-garage",
        stop_id: "Braintree-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-qamnl-garage",
        stop_id: "70103",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-sull",
        stop_id: "29013",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-welln-lot",
        stop_id: "52713",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-wondl-nshore",
        stop_id: "15799",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-wondl-nshore",
        stop_id: "15800",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-welln-garage",
        stop_id: "70033",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-ER-0115-garage",
        stop_id: "ER-0115-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-ER-0117-garage",
        stop_id: "ER-0117-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-ER-0128",
        stop_id: "ER-0128-B0",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-ER-0208",
        stop_id: "ER-0208-B0",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-ER-0227",
        stop_id: "ER-0227-B1",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-ER-0276",
        stop_id: "ER-0276-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FB-0118",
        stop_id: "Dedham Corp Center-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FB-0118",
        stop_id: "FB-0118-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FB-0125",
        stop_id: "FB-0125-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FB-0125",
        stop_id: "FB-0125-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FB-0143",
        stop_id: "FB-0143-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FB-0191",
        stop_id: "FB-0191-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0098-railroad",
        stop_id: "FR-0098-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0115",
        stop_id: "FR-0115-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0167",
        stop_id: "FR-0167-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0167",
        stop_id: "FR-0167-B",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0201",
        stop_id: "FR-0201-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0201",
        stop_id: "FR-0201-B1",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0219",
        stop_id: "FR-0219-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0361-garage",
        stop_id: "FR-0361-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0361-garage",
        stop_id: "FR-0361-B0",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0451-garage",
        stop_id: "FR-0451-B",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-GB-0198",
        stop_id: "GB-0198-B2",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-GB-0229",
        stop_id: "GB-0229-B0",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-GB-0296",
        stop_id: "GB-0296-B0",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-GB-0296",
        stop_id: "GB-0296-B1",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-MBS-0350",
        stop_id: "MBS-0350-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-MM-0277",
        stop_id: "MM-0277-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NB-0064",
        stop_id: "NB-0064-B2",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NB-0072",
        stop_id: "NB-0072-B1",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NB-0072",
        stop_id: "NB-0072-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NEC-1768-garage",
        stop_id: "NEC-1768-B",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NEC-1851-garage",
        stop_id: "NEC-1851-B1",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NEC-1851-garage",
        stop_id: "NEC-1851-B2",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NEC-2139",
        stop_id: "SB-0150-06",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NHRML-0152",
        stop_id: "NHRML-0152-B",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NHRML-0254-garage",
        stop_id: "NHRML-0254-B",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-PB-0281",
        stop_id: "PB-0281-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-SB-0156",
        stop_id: "SB-0156-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WML-0091-wash",
        stop_id: "WML-0091-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0062",
        stop_id: "WR-0062-B0",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0067",
        stop_id: "WR-0067-B0",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0163",
        stop_id: "WR-0163-B1",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0205",
        stop_id: "WR-0205-B1",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0264",
        stop_id: "WR-0264-B2",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-WR-0325",
        stop_id: "WR-0325-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-alfcl-garage",
        stop_id: "14121",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-alfcl-garage",
        stop_id: "Alewife-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-brntn-lot-a",
        stop_id: "Braintree-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-forhl",
        stop_id: "Forest Hills-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-longw",
        stop_id: "70183",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-north-garage",
        stop_id: "70205",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-north-garage",
        stop_id: "BNT-0000-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-north-garage",
        stop_id: "BNT-0000-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-north-garage",
        stop_id: "BNT-0000-06",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-ogmnl",
        stop_id: "Oak Grove-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-orhte",
        stop_id: "15879",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-river",
        stop_id: "70161",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-shmnl",
        stop_id: "70088",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-sstat-garage",
        stop_id: "74611",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-sstat-garage",
        stop_id: "74617",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-sstat-garage",
        stop_id: "NEC-2287-07",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-sstat-garage",
        stop_id: "NEC-2287-09",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-sull",
        stop_id: "29004",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0098-carter",
        stop_id: "FR-0098-B0",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-FR-0098-carter",
        stop_id: "FR-0098-B1",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-MM-0200-garage",
        stop_id: "MM-0200-S",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NHRML-0078-aberjona",
        stop_id: "NHRML-0078-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-NHRML-0218-eastern",
        stop_id: "NHRML-0218-01",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-brntn-garage",
        stop_id: "Braintree-02",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-welln-garage",
        stop_id: "52711",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-welln-garage",
        stop_id: "52720",
        activities: ["PARK_CAR"]
      }),
      InformedEntity.new(%{
        #    facility_id: "park-wondl-garage",
        stop_id: "15797",
        activities: ["PARK_CAR"]
      })
    ]

    Alert.new(
      id: id,
      effect: alert.effect,
      active_period: Enum.map(alert.active_period, &decode_active_period/1),
      informed_entity:
        Enum.map(alert.informed_entity, &decode_informed_entity/1) ++ added_informed_entities
    )
  end

  defp decode_alert(%{id: id, alert: %{} = alert}) do
    [
      Alert.new(
        id: id,
        effect: alert.effect,
        active_period: Enum.map(alert.active_period, &decode_active_period/1),
        informed_entity: Enum.map(alert.informed_entity, &decode_informed_entity/1)
      )
    ]
  end

  defp decode_alert(_) do
    []
  end

  defp decode_active_period(period) do
    start = Map.get(period, :start, 0)
    # 2 ^ 32 - 1, max value for the field
    stop = Map.get(period, :stop, 4_294_967_295)
    {start, stop}
  end

  defp decode_informed_entity(entity) do
    trip = Map.get(entity, :trip, %{})

    InformedEntity.new(
      trip_id: Map.get(trip, :trip_id),
      route_id: Map.get(entity, :route_id),
      direction_id: Map.get(trip, :direction_id) || Map.get(entity, :direction_id),
      route_type: Map.get(entity, :route_type),
      stop_id: Map.get(entity, :stop_id)
    )
  end

  defp time_from_event(%{time: time} = map), do: {time, Map.get(map, :uncertainty, nil)}
  defp time_from_event(_), do: {nil, nil}
end
