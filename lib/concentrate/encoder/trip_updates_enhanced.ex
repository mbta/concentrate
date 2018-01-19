defmodule Concentrate.Encoder.TripUpdatesEnhanced do
  @moduledoc """
  Encodes a list of parsed data into an enhanced.pb file.
  """
  @behaviour Concentrate.Encoder
  alias Concentrate.{TripUpdate, StopTimeUpdate}
  import Concentrate.Encoder.GTFSRealtimeHelpers

  @impl Concentrate.Encoder
  def encode(list) when is_list(list) do
    message = %{
      header: feed_header(),
      entity: feed_entity(list)
    }

    Jason.encode!(message)
  end

  def feed_header do
    timestamp = :erlang.system_time(:seconds)

    %{
      gtfs_realtime_version: "2.0",
      timestamp: timestamp
    }
  end

  def feed_entity(list) do
    list
    |> group
    |> Enum.flat_map(&build_entity/1)
  end

  defp build_entity({%TripUpdate{} = update, _vps, [_ | _] = stus}) do
    [
      %{
        id: "#{:erlang.phash2(update)}",
        trip_update: %{
          trip:
            drop_nil_values(%{
              trip_id: TripUpdate.trip_id(update),
              route_id: TripUpdate.route_id(update),
              direction_id: TripUpdate.direction_id(update),
              start_time: TripUpdate.start_time(update),
              start_date: encode_date(TripUpdate.start_date(update)),
              schedule_relationship: TripUpdate.schedule_relationship(update)
            }),
          stop_time_update: Enum.map(stus, &build_stop_time_update/1)
        }
      }
    ]
  end

  defp build_entity(_) do
    []
  end

  defp build_stop_time_update(%StopTimeUpdate{} = update) do
    drop_nil_values(%{
      stop_id: StopTimeUpdate.stop_id(update),
      stop_sequence: StopTimeUpdate.stop_sequence(update),
      arrival: stop_time_event(StopTimeUpdate.arrival_time(update)),
      departure: stop_time_event(StopTimeUpdate.departure_time(update)),
      schedule_relationship: StopTimeUpdate.schedule_relationship(update),
      boarding_status: StopTimeUpdate.status(update)
    })
  end

  defp stop_time_event(nil) do
    nil
  end

  defp stop_time_event(unix_timestamp) do
    %{
      time: unix_timestamp
    }
  end
end
