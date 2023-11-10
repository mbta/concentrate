defmodule Concentrate.Encoder.TripUpdates do
  @moduledoc """
  Encodes a list of parsed data into a TripUpdates.pb file.
  """
  @behaviour Concentrate.Encoder
  alias Concentrate.StopTimeUpdate
  import Concentrate.Encoder.GTFSRealtimeHelpers
  alias TransitRealtime, as: GTFS
  alias TransitRealtime.FeedMessage

  @impl Concentrate.Encoder
  def encode_groups(groups, opts \\ []) when is_list(groups) do
    message = %FeedMessage{
      header: feed_header(opts),
      entity: trip_update_feed_entity(groups, &build_stop_time_update/1)
    }

    FeedMessage.encode(message)
  end

  def build_stop_time_update(update) do
    arrival =
      stop_time_event(StopTimeUpdate.arrival_time(update), StopTimeUpdate.uncertainty(update))

    departure =
      stop_time_event(StopTimeUpdate.departure_time(update), StopTimeUpdate.uncertainty(update))

    relationship = StopTimeUpdate.schedule_relationship(update)

    if is_map(arrival) or is_map(departure) or relationship != nil do
      %GTFS.TripUpdate.StopTimeUpdate{
        stop_id: StopTimeUpdate.stop_id(update),
        stop_sequence: StopTimeUpdate.stop_sequence(update),
        arrival: arrival,
        departure: departure,
        schedule_relationship: relationship
      }
    else
      :skip
    end
  end
end
