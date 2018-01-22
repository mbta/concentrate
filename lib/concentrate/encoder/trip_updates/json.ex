defmodule Concentrate.Encoder.TripUpdates.JSON do
  @moduledoc """
  Encodes a list of parsed data into a TripUpdates.json file.
  """
  @behaviour Concentrate.Encoder
  alias Concentrate.Encoder.TripUpdates

  @impl Concentrate.Encoder
  def encode(list) when is_list(list) do
    message = %{
      header: TripUpdates.feed_header(),
      entity: TripUpdates.feed_entity(list)
    }

    Jason.encode!(message)
  end
end
