defmodule Concentrate.Encoder.TripUpdatesEnhanced do
  @moduledoc """
  Encodes a list of parsed data into an enhanced.pb file.
  """
  @behaviour Concentrate.Encoder
  alias Concentrate.GTFS
  alias TransitRealtime, as: GTFS
  alias TransitRealtime.FeedMessage
  alias Concentrate.{StopTimeUpdate, TripDescriptor}
  import Concentrate.Encoder.GTFSRealtimeHelpers

  @impl Concentrate.Encoder
  def encode_groups(groups, opts \\ []) when is_list(groups) do
    message =
      %FeedMessage{
        header: feed_header(opts),
        entity: trip_update_feed_entity(groups, &build_stop_time_update/1, &enhanced_data/1)
      }
      |> dbg()

    Protobuf.JSON.encode!(message)
  end

  defp enhanced_data(update) do
    TripDescriptor.route_pattern_id(update)
  end

  defp build_stop_time_update(update) do
    %GTFS.TripUpdate.StopTimeUpdate{
      stop_id: StopTimeUpdate.stop_id(update),
      stop_sequence: StopTimeUpdate.stop_sequence(update),
      arrival:
        stop_time_event(StopTimeUpdate.arrival_time(update), StopTimeUpdate.uncertainty(update)),
      departure:
        stop_time_event(StopTimeUpdate.departure_time(update), StopTimeUpdate.uncertainty(update)),
      schedule_relationship: schedule_relationship(StopTimeUpdate.schedule_relationship(update))
    }
    |> GTFS.TripUpdate.StopTimeUpdate.put_extension(
      TransitRealtime.PbExtension,
      :boarding_status,
      StopTimeUpdate.status(update)
    )
    |> GTFS.TripUpdate.StopTimeUpdate.put_extension(
      TransitRealtime.PbExtension,
      :platform_id,
      StopTimeUpdate.platform_id(update)
    )
  end
end
