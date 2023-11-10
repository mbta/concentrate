defmodule Concentrate.Encoder.VehiclePositions.JSON do
  @moduledoc """
  Encodes a list of parsed data into a VehiclePositions.json file.
  """
  @behaviour Concentrate.Encoder
  alias TransitRealtime.FeedMessage
  alias Concentrate.Encoder.VehiclePositions
  import Concentrate.Encoder.GTFSRealtimeHelpers

  @impl Concentrate.Encoder
  def encode_groups(groups, opts \\ []) when is_list(groups) do
    message = %FeedMessage{
      header: feed_header(opts),
      entity: Enum.flat_map(groups, &VehiclePositions.build_entity/1)
    }

    Protobuf.JSON.encode!(message)
  end
end
