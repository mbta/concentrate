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

  def filter(%TripDescriptor{} = td, suffix_matches) do
    vehicle_id = TripDescriptor.vehicle_id(td)
    td = possibly_strip_vehicle_id(vehicle_id, td, suffix_matches)

    {:cont, td}
  end

  def filter(other, _), do: {:cont, other}

  defp possibly_strip_vehicle_id(nil, td, _), do: td

  defp possibly_strip_vehicle_id(vehicle_id, td, suffix_matches) do
    if String.ends_with?(vehicle_id, suffix_matches) do
      TripDescriptor.update_vehicle_id(td, nil)
    else
      td
    end
  end
end
