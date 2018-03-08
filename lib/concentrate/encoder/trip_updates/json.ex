defmodule Concentrate.Encoder.TripUpdates.JSON do
  @moduledoc """
  Encodes a list of parsed data into a TripUpdates.json file.
  """
  @behaviour Concentrate.Encoder
  alias Concentrate.Encoder.TripUpdates

  @impl Concentrate.Encoder
  def encode_groups(groups) when is_list(groups) do
    message = %{
      header: TripUpdates.feed_header(),
      entity: Enum.flat_map(groups, &TripUpdates.build_entity/1)
    }

    Jason.encode!(message)
  end
end
