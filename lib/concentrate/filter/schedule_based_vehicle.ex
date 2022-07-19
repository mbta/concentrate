defmodule Concentrate.Filter.ScheduleBasedVehicle do
  @moduledoc """
  Rejects vehicles which don't have a trip ID.
  """
  alias Concentrate.VehiclePosition
  @behaviour Concentrate.Filter

  @impl Concentrate.Filter
  def filter(%VehiclePosition{trip_id: trip_id} = vp) do
    if String.ends_with?(trip_id, "schedBasedVehicle") do
      :skip
    else
      {:cont, vp}
    end
  end

  def filter(other), do: {:cont, other}
end
