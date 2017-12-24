defmodule Concentrate.Encoder.VehiclePositions do
  @moduledoc """
  Encodes a list of parsed data into a VehiclePositions.pb file.
  """
  @behaviour Concentrate.Encoder
  alias Concentrate.{TripUpdate, VehiclePosition}
  alias Concentrate.Parser.GTFSRealtime
  import Concentrate.Encoder.GTFSRealtimeGroup

  alias GTFSRealtime.{
    FeedMessage,
    FeedHeader,
    FeedEntity,
    TripDescriptor,
    VehicleDescriptor,
    Position
  }

  @impl Concentrate.Encoder
  def encode(list) when is_list(list) do
    message = %FeedMessage{
      header: feed_header(),
      entity: feed_entity(list)
    }

    FeedMessage.encode(message)
  end

  def feed_header do
    timestamp = :erlang.system_time(:seconds)

    %FeedHeader{
      gtfs_realtime_version: "2.0",
      timestamp: timestamp
    }
  end

  def feed_entity(list) do
    list
    |> group
    |> Enum.flat_map(&build_entity/1)
  end

  defp build_entity({%TripUpdate{} = update, vps, _stus}) do
    trip = trip_descriptor(update)

    for vp <- vps do
      %FeedEntity{
        id: entity_id(vp),
        vehicle: build_vehicle(vp, trip)
      }
    end
  end

  defp build_entity({nil, vps, _stus}) do
    # vehicles without a trip
    for vp <- vps do
      trip =
        if trip_id = VehiclePosition.trip_id(vp) do
          %TripDescriptor{
            trip_id: trip_id,
            schedule_relationship: :UNSCHEDULED
          }
        end

      %FeedEntity{
        id: entity_id(vp),
        vehicle: build_vehicle(vp, trip)
      }
    end
  end

  defp build_vehicle(%VehiclePosition{} = vp, trip) do
    descriptor = %VehicleDescriptor{
      id: VehiclePosition.id(vp),
      label: VehiclePosition.label(vp),
      license_plate: VehiclePosition.license_plate(vp)
    }

    position = %Position{
      latitude: VehiclePosition.latitude(vp),
      longitude: VehiclePosition.longitude(vp),
      bearing: VehiclePosition.bearing(vp),
      speed: VehiclePosition.speed(vp)
    }

    %GTFSRealtime.VehiclePosition{
      trip: trip,
      vehicle: descriptor,
      position: position,
      stop_id: VehiclePosition.stop_id(vp),
      current_stop_sequence: VehiclePosition.stop_sequence(vp),
      current_status: VehiclePosition.status(vp),
      timestamp: time(VehiclePosition.last_updated(vp))
    }
  end

  defp entity_id(vp) do
    VehiclePosition.id(vp) || VehiclePosition.trip_id(vp) || "#{:erlang.phash2(vp)}"
  end

  def time(nil) do
    nil
  end

  def time(%DateTime{} = dt) do
    DateTime.to_unix(dt)
  end

  defp trip_descriptor(update) do
    %TripDescriptor{
      trip_id: TripUpdate.trip_id(update),
      route_id: TripUpdate.route_id(update),
      direction_id: TripUpdate.direction_id(update),
      start_time: TripUpdate.start_time(update),
      start_date: TripUpdate.start_date(update),
      schedule_relationship: TripUpdate.schedule_relationship(update)
    }
  end
end
