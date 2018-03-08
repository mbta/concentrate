defmodule Concentrate.Encoder.VehiclePositions.JSON do
  @moduledoc """
  Encodes a list of parsed data into a VehiclePositions.json file.
  """
  @behaviour Concentrate.Encoder
  alias Concentrate.Encoder.VehiclePositions

  @impl Concentrate.Encoder
  def encode_groups(groups) when is_list(groups) do
    message = %{
      header: VehiclePositions.feed_header(),
      entity: Enum.flat_map(groups, &VehiclePositions.build_entity/1)
    }

    Jason.encode!(message)
  end
end
