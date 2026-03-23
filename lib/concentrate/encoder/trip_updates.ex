defmodule Concentrate.Encoder.TripUpdates do
  @moduledoc """
  Encodes a list of parsed data into a TripUpdates.pb file.
  """
  @behaviour Concentrate.Encoder
  require Logger
  alias Concentrate.StopTimeUpdate
  import Concentrate.Encoder.GTFSRealtimeHelpers

  @impl Concentrate.Encoder
  def encode_groups(groups, opts \\ []) when is_list(groups) do
    groups = Enum.reject(groups, &non_revenue?/1)

    message = %{
      header: feed_header(opts),
      entity: trip_update_feed_entity(groups, &build_stop_time_update/1)
    }

    :gtfs_realtime_proto.encode_msg(message, :FeedMessage)
  end

  def build_stop_time_update(update) do
    arrival =
      stop_time_event(StopTimeUpdate.arrival_time(update), StopTimeUpdate.uncertainty(update))

    departure =
      stop_time_event(StopTimeUpdate.departure_time(update), StopTimeUpdate.uncertainty(update))

    relationship = schedule_relationship(StopTimeUpdate.schedule_relationship(update))

    stop_time_properties = stop_time_properties(StopTimeUpdate.assigned_stop_id(update))

    # TEMP: log stop_time_properties while encoding
    if stop_time_properties do
      Logger.info(
        "event=encode_stop_time_properties stop_time_properties=#{inspect(stop_time_properties)} trip_id=#{StopTimeUpdate.trip_id(update)}"
      )
    end

    if (is_map(arrival) or is_map(departure) or relationship != nil) and
         StopTimeUpdate.passthrough_time(update) == nil do
      drop_nil_values(%{
        stop_id: StopTimeUpdate.stop_id(update),
        stop_sequence: StopTimeUpdate.stop_sequence(update),
        arrival: arrival,
        departure: departure,
        schedule_relationship: relationship,
        stop_time_properties: stop_time_properties
      })
    else
      :skip
    end
  end
end
