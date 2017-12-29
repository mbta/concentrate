defmodule Concentrate.Parser.GTFSRealtime do
  @moduledoc """
  Parser for [GTFS-Realtime](https://developers.google.com/transit/gtfs-realtime/) ProtoBuf files.
  """
  @behaviour Concentrate.Parser
  use Protobuf, from: Path.expand("gtfs-realtime.proto", __DIR__)
  alias Concentrate.{VehiclePosition, TripUpdate, StopTimeUpdate, Alert, Alert.InformedEntity}

  @impl Concentrate.Parser
  def parse(binary) when is_binary(binary) do
    for message <- [__MODULE__.FeedMessage.decode(binary)],
        entity <- message.entity,
        decoded <- decode_feed_entity(entity) do
      decoded
    end
  end

  def decode_feed_entity(entity) do
    vp = decode_vehicle(entity.vehicle)
    stop_updates = decode_trip_update(entity.trip_update)
    alerts = decode_alert(entity)
    alerts ++ vp ++ stop_updates
  end

  def decode_vehicle(nil) do
    []
  end

  def decode_vehicle(vp) do
    decode_trip_descriptor(vp.trip) ++
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
          last_updated: if(vp.timestamp, do: DateTime.from_unix!(vp.timestamp))
        )
      ]
  end

  def decode_trip_update(nil) do
    []
  end

  def decode_trip_update(trip_update) do
    tu = decode_trip_descriptor(trip_update.trip)

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
    {:ok, date} =
      Date.new(
        String.to_integer(year_str),
        String.to_integer(month_str),
        String.to_integer(day_str)
      )

    date
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
    start = DateTime.from_unix!(start || 0)

    stop =
      if stop do
        DateTime.from_unix!(stop)
      else
        # 2 ^ 32 - 1
        DateTime.from_unix!(4_294_967_295)
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
  defp time_from_event(%{time: nil}), do: nil
  defp time_from_event(%{time: time}), do: DateTime.from_unix!(time)
end
