defmodule Concentrate.Filter.VehicleWithNoTrip do
  @moduledoc """
  Rejects vehicles which don't have a trip ID.
  """
  alias Concentrate.VehiclePosition
  @behaviour Concentrate.Filter

  @impl Concentrate.Filter
  def init do
    []
  end

  @impl Concentrate.Filter
  def filter(%VehiclePosition{} = vp, state) do
    if VehiclePosition.trip_id(vp) do
      {:cont, vp, state}
    else
      {:skip, state}
    end
  end

  def filter(other, state) do
    {:cont, other, state}
  end
end
