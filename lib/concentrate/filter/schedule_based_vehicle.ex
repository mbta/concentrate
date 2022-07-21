defmodule Concentrate.Filter.ScheduleBasedVehicle do
  @moduledoc """
  Rejects vehicles which end in a specific string provided via config at compile time.

  Example config:
    config :concentrate,
      filters: [
        {
          Concentrate.Filter.ScheduleBasedVehicle,
          suffix_matches: ["ignore_suffix_1", "ignore_suffix_2"]
        }
      ]

  If no suffix match provided, this filter does nothing.
  """
  alias Concentrate.VehiclePosition
  @behaviour Concentrate.Filter

  config_path = [:filters, __MODULE__, :suffix_matches]
  @suffix_matches Application.compile_env(:concentrate, config_path, [])

  @impl Concentrate.Filter
  def filter(vp, suffix_matches \\ @suffix_matches)
  def filter(vp, []), do: {:cont, vp}

  def filter(%VehiclePosition{trip_id: trip_id} = vp, suffix_matches) do
    if String.ends_with?(trip_id, suffix_matches) do
      :skip
    else
      {:cont, vp}
    end
  end

  def filter(other, _), do: {:cont, other}
end
