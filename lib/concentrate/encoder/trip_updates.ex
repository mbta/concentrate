defmodule Concentrate.Encoder.TripUpdates do
  @moduledoc """
  Encodes a list of parsed data into a TripUpdates.pb file.
  """
  @behaviour Concentrate.Encoder
  alias Concentrate.{TripUpdate, StopTimeUpdate}
  alias Concentrate.Parser.GTFSRealtime
  alias GTFSRealtime.{FeedMessage, FeedHeader, FeedEntity, TripDescriptor}
  import Concentrate.Encoder.GTFSRealtimeHelpers

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

  defp build_entity({%TripUpdate{} = update, _vps, stus}) do
    trip_id = TripUpdate.trip_id(update)
    [
      %FeedEntity{
        id: trip_id || "#{:erlang.phash2(update)}",

        trip_update: %GTFSRealtime.TripUpdate{
          trip: %TripDescriptor{
            trip_id: trip_id,
            route_id: TripUpdate.route_id(update),
            direction_id: TripUpdate.direction_id(update),
            start_time: TripUpdate.start_time(update),
            start_date: encode_date(TripUpdate.start_date(update)),
            schedule_relationship: TripUpdate.schedule_relationship(update)
          },
          stop_time_update: Enum.map(stus, &build_stop_time_update/1)
        }
      }
    ]
  end

  defp build_entity(_) do
    []
  end

  defp build_stop_time_update(%StopTimeUpdate{} = update) do
    %GTFSRealtime.TripUpdate.StopTimeUpdate{
      stop_id: StopTimeUpdate.stop_id(update),
      stop_sequence: StopTimeUpdate.stop_sequence(update),
      arrival: stop_time_event(StopTimeUpdate.arrival_time(update)),
      departure: stop_time_event(StopTimeUpdate.departure_time(update)),
      schedule_relationship: StopTimeUpdate.schedule_relationship(update)
    }
  end

  defp stop_time_event(nil) do
    nil
  end

  defp stop_time_event(unix_timestamp) do
    %GTFSRealtime.TripUpdate.StopTimeEvent{
      time: unix_timestamp
    }
  end
end
