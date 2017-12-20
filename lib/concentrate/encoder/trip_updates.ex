defmodule Concentrate.Encoder.TripUpdates do
  @moduledoc """
  Encodes a list of parsed data into a TripUpdates.pb file.
  """
  @behaviour Concentrate.Encoder
  alias Concentrate.{TripUpdate, StopTimeUpdate}
  alias Concentrate.Parser.GTFSRealtime
  alias GTFSRealtime.{FeedMessage, FeedHeader, FeedEntity, TripDescriptor}

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
    |> Enum.reject(&(&1.trip_update.stop_time_update == []))
    |> reverse_entity
  end

  defp build_entity(%TripUpdate{} = update, acc) do
    entity = %FeedEntity{
      id: "#{:erlang.phash2(update)}",
      trip_update: %GTFSRealtime.TripUpdate{
        trip: %TripDescriptor{
          trip_id: TripUpdate.trip_id(update),
          route_id: TripUpdate.route_id(update),
          direction_id: TripUpdate.direction_id(update),
          start_time: TripUpdate.start_time(update),
          start_date: TripUpdate.start_date(update),
          schedule_relationship: TripUpdate.schedule_relationship(update)
        },
        stop_time_update: []
      }
    }

    [entity | acc]
  end

  defp build_entity(%StopTimeUpdate{} = update, acc) do
    # make sure we're updating the right trip
    trip_id = StopTimeUpdate.trip_id(update)
    {update_entity, prefix, suffix} = find_entity(acc, trip_id)

    stu = %GTFSRealtime.TripUpdate.StopTimeUpdate{
      stop_id: StopTimeUpdate.stop_id(update),
      stop_sequence: StopTimeUpdate.stop_sequence(update),
      arrival: stop_time_event(StopTimeUpdate.arrival_time(update)),
      departure: stop_time_event(StopTimeUpdate.departure_time(update)),
      schedule_relationship: StopTimeUpdate.schedule_relationship(update)
    }

    stop_time_update = [stu | update_entity.trip_update.stop_time_update]
    update_entity = put_in(update_entity.trip_update.stop_time_update, stop_time_update)

    prefix ++ [update_entity | suffix]
  end

  defp build_entity(_, acc) do
    acc
  end

  defp reverse_entity(acc) do
    acc
    |> Enum.map(fn update ->
      stop_time_update = Enum.reverse(update.trip_update.stop_time_update)
      put_in(update.trip_update.stop_time_update, stop_time_update)
    end)
    |> Enum.reverse()
  end

  defp stop_time_event(nil) do
    nil
  end

  defp stop_time_event(%DateTime{} = dt) do
    %GTFSRealtime.TripUpdate.StopTimeEvent{
      time: DateTime.to_unix(dt)
    }
  end

  defp find_entity(list, trip_id, prefix \\ [])

  defp find_entity([head | tail], trip_id, prefix) do
    if head.trip_update.trip.trip_id == trip_id do
      {head, Enum.reverse(prefix), tail}
    else
      find_entity(tail, trip_id, [head | prefix])
    end
  end
end
