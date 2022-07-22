defmodule Concentrate.Filter.FilterTripUpdateVehicles do
  @moduledoc """
  Rejects vehicle ids which end in a specific string provided via config at compile time.

  Example config:
    config :concentrate,
      filters: [
        {
          Concentrate.Filter.FilterTripUpdateVehicles,
          suffix_matches: ["ignore_suffix_1", "ignore_suffix_2"]
        }
      ]

  If no suffix match provided, this filter does nothing.
  """
  alias Concentrate.TripDescriptor
  @behaviour Concentrate.Filter

  config_path = [:filters, __MODULE__, :suffix_matches]
  @suffix_matches Application.compile_env(:concentrate, config_path, [])

  @impl Concentrate.Filter
  def filter(td, suffix_matches \\ @suffix_matches)
  def filter(td, []), do: {:cont, td}

  def filter(%TripDescriptor{trip_id: trip_id} = td, suffix_matches) do
    if String.ends_with?(trip_id, suffix_matches) do
      {:cont, %{td | vehicle_id: nil}}
    else
      {:cont, td}
    end
  end

  def filter(other, _), do: {:cont, other}
end
