defmodule Concentrate.Encoder.VehiclePositions do
  @moduledoc """
  Encodes a list of parsed data into a VehiclePositions.pb file.
  """
  @behaviour Concentrate.Encoder
  alias Concentrate.{TripUpdate, VehiclePosition}
  alias Concentrate.Parser.GTFSRealtime

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
    |> Enum.reduce([], &build_entity/2)
    |> Enum.reject(&is_nil(&1.vehicle.vehicle))
    |> Enum.reverse()
  end

  defp build_entity(%TripUpdate{} = update, acc) do
    entity = %FeedEntity{
      id: "#{:erlang.phash2(update)}",
      vehicle: %GTFSRealtime.VehiclePosition{
        trip: %TripDescriptor{
          trip_id: TripUpdate.trip_id(update),
          route_id: TripUpdate.route_id(update),
          direction_id: TripUpdate.direction_id(update),
          start_time: TripUpdate.start_time(update),
          start_date: TripUpdate.start_date(update),
          schedule_relationship: TripUpdate.schedule_relationship(update)
        }
      }
    }

    [entity | acc]
  end

  defp build_entity(%VehiclePosition{} = vp, acc) do
    # make sure we're updating the right trip
    trip_id = VehiclePosition.trip_id(vp)

    {update_entity, prefix, suffix} =
      case find_entity(acc, trip_id) do
        nil ->
          {
            %FeedEntity{id: "#{:erlang.phash2(vp)}", vehicle: %GTFSRealtime.VehiclePosition{}},
            [],
            acc
          }

        other ->
          other
      end

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

    vehicle = %{
      update_entity.vehicle
      | vehicle: descriptor,
        position: position,
        stop_id: VehiclePosition.stop_id(vp),
        current_stop_sequence: VehiclePosition.stop_sequence(vp),
        current_status: VehiclePosition.status(vp),
        timestamp: time(VehiclePosition.last_updated(vp))
    }

    update_entity = put_in(update_entity.vehicle, vehicle)
    prefix ++ [update_entity | suffix]
  end

  defp build_entity(_, acc) do
    acc
  end

  def time(nil) do
    nil
  end

  def time(%DateTime{} = dt) do
    DateTime.to_unix(dt)
  end

  defp find_entity(list, trip_id, prefix \\ [])

  defp find_entity(_, nil, _) do
    nil
  end

  defp find_entity([head | tail], trip_id, prefix) do
    case head.vehicle do
      %{trip: %{trip_id: ^trip_id}} ->
        {head, Enum.reverse(prefix), tail}

      _ ->
        find_entity(tail, trip_id, [head | prefix])
    end
  end
end
