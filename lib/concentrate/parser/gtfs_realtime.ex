defmodule Concentrate.Parser.GTFSRealtime do
  @moduledoc """
  Parser for [GTFS-Realtime](https://developers.google.com/transit/gtfs-realtime/) ProtoBuf files.

  Options:

  * routes: a list of route IDs to include in the output. Other route IDs
  (including unknown routes) will not be included.

  """
  @behaviour Concentrate.Parser
  use Protobuf, from: Path.expand("gtfs-realtime.proto", __DIR__)
  alias Concentrate.{VehiclePosition, TripUpdate, StopTimeUpdate, Alert, Alert.InformedEntity}

  @impl Concentrate.Parser
  def parse(binary, opts) when is_binary(binary) and is_list(opts) do
    routes = Keyword.fetch(opts, :routes)
    message = :gtfs_realtime_proto.decode_msg(binary, :FeedMessage, [])
    Enum.flat_map(message.entity, &decode_feed_entity(&1, routes))
  end

  def decode_feed_entity(entity, routes) do
    vp = decode_vehicle(Map.get(entity, :vehicle), routes)
    stop_updates = decode_trip_update(Map.get(entity, :trip_update), routes)
    alerts = decode_alert(entity)
    List.flatten([alerts, vp, stop_updates])
  end

  def decode_vehicle(nil, _opts) do
    []
  end

  def decode_vehicle(vp, routes) do
    tu = decode_trip_descriptor(vp)
    decode_vehicle_position(tu, vp, routes)
  end

  defp decode_vehicle_position([tu], vp, {:ok, routes}) do
    if TripUpdate.route_id(tu) in routes do
      decode_vehicle_position([tu], vp, :error)
    else
      []
    end
  end

  defp decode_vehicle_position(tu, vp, _) do
    trip_id =
      case vp do
        %{trip: %{trip_id: id}} -> id
        _ -> nil
      end

    vehicle = vp.vehicle
    position = vp.position

    tu ++
      [
        VehiclePosition.new(
          id: Map.get(vehicle, :id),
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
          last_updated: Map.get(vp, :timestamp)
        )
      ]
  end

  def decode_trip_update(nil, _routes) do
    []
  end

  def decode_trip_update(trip_update, routes) do
    tu = decode_trip_descriptor(trip_update)
    decode_stop_updates(tu, trip_update, routes)
  end

  defp decode_stop_updates([tu], trip_update, {:ok, routes}) do
    if TripUpdate.route_id(tu) in routes do
      decode_stop_updates([tu], trip_update, :error)
    else
      []
    end
  end

  defp decode_stop_updates(tu, trip_update, _) do
    trip_id = Map.get(trip_update.trip, :trip_id)

    stop_updates =
      for stu <- trip_update.stop_time_update do
        StopTimeUpdate.new(
          trip_id: trip_id,
          stop_id: Map.get(stu, :stop_id),
          stop_sequence: Map.get(stu, :stop_sequence),
          schedule_relationship: Map.get(stu, :schedule_relationship),
          arrival_time: time_from_event(Map.get(stu, :arrival)),
          departure_time: time_from_event(Map.get(stu, :departure))
        )
      end

    tu ++ stop_updates
  end

  defp decode_trip_descriptor(%{trip: trip}) do
    [
      TripUpdate.new(
        trip_id: Map.get(trip, :trip_id),
        route_id: Map.get(trip, :route_id),
        direction_id: Map.get(trip, :direction_id),
        start_date: date(Map.get(trip, :start_date)),
        start_time: Map.get(trip, :start_time),
        schedule_relationship: Map.get(trip, :schedule_relationship)
      )
    ]
  end

  defp decode_trip_descriptor(_) do
    []
  end

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
    # 2 ^ 64 - 1
    stop = Map.get(period, :stop, 1.8446744073709552e19)
    {start, stop}
  end

  defp decode_informed_entity(entity) do
    trip = Map.get(entity, :trip, %{})

    InformedEntity.new(
      trip_id: Map.get(trip, :trip_id),
      route_id: Map.get(entity, :route_id),
      direction_id: Map.get(trip, :direction_id),
      route_type: Map.get(entity, :route_type),
      stop_id: Map.get(entity, :stop_id)
    )
  end

  defp time_from_event(%{time: time}), do: time
  defp time_from_event(_), do: nil
end
