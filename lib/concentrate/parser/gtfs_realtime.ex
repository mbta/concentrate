defmodule Concentrate.Parser.GTFSRealtime do
  @moduledoc """
  Parser for [GTFS-Realtime](https://developers.google.com/transit/gtfs-realtime/) ProtoBuf files.
  """
  @behaviour Concentrate.Parser
  use Protobuf, from: Path.expand("gtfs-realtime.proto", __DIR__)
  alias Concentrate.{VehiclePosition, TripUpdate, StopTimeUpdate}

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
    vp ++ stop_updates
  end

  def decode_vehicle(nil) do
    []
  end

  def decode_vehicle(vp) do
    [
      TripUpdate.new(
        trip_id: vp.trip.trip_id,
        route_id: vp.trip.route_id,
        direction_id: vp.trip.direction_id
      ),
      VehiclePosition.new(
        id: vp.vehicle.id,
        trip_id: vp.trip.trip_id,
        stop_id: vp.stop_id,
        label: vp.vehicle.label,
        license_plate: vp.vehicle.license_plate,
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
    tu =
      TripUpdate.new(
        trip_id: trip_update.trip.trip_id,
        route_id: trip_update.trip.route_id,
        direction_id: trip_update.trip.direction_id,
        schedule_relationship: trip_update.trip.schedule_relationship
      )

    stop_updates =
      for stu <- trip_update.stop_time_update do
        StopTimeUpdate.new(
          trip_id: trip_update.trip.trip_id,
          stop_id: stu.stop_id,
          stop_sequence: stu.stop_sequence,
          schedule_relationship: stu.schedule_relationship,
          arrival_time: time_from_event(stu.arrival),
          departure_time: time_from_event(stu.departure)
        )
      end

    [tu | stop_updates]
  end

  defp time_from_event(nil), do: nil
  defp time_from_event(%{time: nil}), do: nil
  defp time_from_event(%{time: time}), do: DateTime.from_unix!(time)
end
