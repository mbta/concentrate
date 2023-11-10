defmodule Concentrate.Encoder.TripUpdates.JSON do
  @moduledoc """
  Encodes a list of parsed data into a TripUpdates.json file.
  """
  @behaviour Concentrate.Encoder
  alias TransitRealtime.FeedMessage
  alias Concentrate.Encoder.TripUpdates
  import Concentrate.Encoder.GTFSRealtimeHelpers

  @impl Concentrate.Encoder
  def encode_groups(groups, opts \\ []) when is_list(groups) do
    message = %FeedMessage{
      header: feed_header(opts),
      entity: trip_update_feed_entity(groups, &TripUpdates.build_stop_time_update/1)
    }

    Protobuf.JSON.encode!(message)
  end
end
