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
    message = __MODULE__.FeedMessage.decode(binary)
    Enum.flat_map(message.entity, &decode_feed_entity(&1, routes))
  end

  def decode_feed_entity(entity, routes) do
    vp = decode_vehicle(entity.vehicle, routes)
    stop_updates = decode_trip_update(entity.trip_update, routes)
    alerts = decode_alert(entity)
    List.flatten([alerts, vp, stop_updates])
  end

  def decode_vehicle(nil, _opts) do
    []
  end

  def decode_vehicle(vp, routes) do
    tu = decode_trip_descriptor(vp.trip)
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
    tu ++
      [
        VehiclePosition.new(
          id: optional_copy(vp.vehicle.id),
          trip_id: if(vp.trip, do: optional_copy(vp.trip.trip_id)),
          stop_id: optional_copy(vp.stop_id),
          label: optional_copy(vp.vehicle.label),
          license_plate: optional_copy(vp.vehicle.license_plate),
          latitude: vp.position.latitude,
          longitude: vp.position.longitude,
          bearing: vp.position.bearing,
          speed: vp.position.speed,
          odometer: vp.position.odometer,
          status: vp.current_status,
          stop_sequence: vp.current_stop_sequence,
          last_updated: vp.timestamp
        )
      ]
  end

  def decode_trip_update(nil, _routes) do
    []
  end

  def decode_trip_update(trip_update, routes) do
    tu = decode_trip_descriptor(trip_update.trip)
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
    stop_updates =
      for stu <- trip_update.stop_time_update do
        StopTimeUpdate.new(
          trip_id: optional_copy(trip_update.trip.trip_id),
          stop_id: optional_copy(stu.stop_id),
          stop_sequence: stu.stop_sequence,
          schedule_relationship: stu.schedule_relationship,
          arrival_time: time_from_event(stu.arrival),
          departure_time: time_from_event(stu.departure)
        )
      end

    tu ++ stop_updates
  end

  defp optional_copy(binary) when is_binary(binary), do: :binary.copy(binary)
  defp optional_copy(nil), do: nil

  defp decode_trip_descriptor(nil) do
    []
  end

  defp decode_trip_descriptor(trip) do
    [
      TripUpdate.new(
        trip_id: optional_copy(trip.trip_id),
        route_id: optional_copy(trip.route_id),
        direction_id: trip.direction_id,
        start_date: date(trip.start_date),
        start_time: optional_copy(trip.start_time),
        schedule_relationship: trip.schedule_relationship
      )
    ]
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

  defp decode_alert(%{alert: nil}) do
    []
  end

  defp decode_alert(%{id: id, alert: alert}) do
    [
      Alert.new(
        id: id,
        effect: alert.effect,
        active_period: Enum.map(alert.active_period, &decode_active_period/1),
        informed_entity: Enum.map(alert.informed_entity, &decode_informed_entity/1)
      )
    ]
  end

  defp decode_active_period(%{start: start, end: stop}) do
    start = start || 0

    stop =
      if stop do
        stop
      else
        # 2 ^ 32 - 1
        4_294_967_295
      end

    {start, stop}
  end

  defp decode_informed_entity(entity) do
    InformedEntity.new(
      trip_id: if(entity.trip, do: entity.trip.trip_id),
      route_id: entity.route_id,
      direction_id: if(entity.trip, do: entity.trip.direction_id),
      route_type: entity.route_type,
      stop_id: entity.stop_id
    )
  end

  defp time_from_event(nil), do: nil
  defp time_from_event(%{time: time}), do: time
end
