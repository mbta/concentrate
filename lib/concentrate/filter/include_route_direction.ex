defmodule Concentrate.Filter.IncludeRouteDirection do
  @moduledoc """
  Adds route/direction ID for TripUpdates.
  """
  @behaviour Concentrate.Filter
  alias Concentrate.TripUpdate
  alias Concentrate.Filter.GTFS.Trips

  @impl Concentrate.Filter
  def init do
    Trips
  end

  @impl Concentrate.Filter
  def filter(%TripUpdate{} = tu, module) do
    trip_id = TripUpdate.trip_id(tu)
    tu = update_route_direction(tu, trip_id, module)
    {:cont, tu, module}
  end

  def filter(other, state) do
    {:cont, other, state}
  end

  defp update_route_direction(tu, nil, _) do
    tu
  end

  defp update_route_direction(tu, trip_id, module) do
    tu =
      if TripUpdate.route_id(tu) do
        tu
      else
        TripUpdate.update_route_id(tu, module.route_id(trip_id))
      end

    if TripUpdate.direction_id(tu) do
      tu
    else
      TripUpdate.update_direction_id(tu, module.direction_id(trip_id))
    end
  end
end
