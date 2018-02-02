defmodule Concentrate.Encoder.VehiclePositions.JSON do
  @moduledoc """
  Encodes a list of parsed data into a VehiclePositions.json file.
  """
  @behaviour Concentrate.Encoder
  alias Concentrate.Encoder.VehiclePositions
  import Concentrate.Encoder.GTFSRealtimeHelpers

  @impl Concentrate.Encoder
  def encode(list) when is_list(list) do
    message = %{
      header: feed_header(),
      entity: VehiclePositions.feed_entity(list)
    }

    Jason.encode!(message)
  end
end
