defmodule Concentrate.Filter.IncludeRouteDirection do
  @moduledoc """
  Adds route/direction ID for TripUpdates.
  """
  @behaviour Concentrate.Filter
  alias Concentrate.GTFS.Trips
  alias Concentrate.TripDescriptor

  @impl Concentrate.Filter
  def filter(item, module \\ Trips)

  def filter(%TripDescriptor{} = td, module) do
    trip_id = TripDescriptor.trip_id(td)
    td = update_route_direction(td, trip_id, module)
    {:cont, td}
  end

  def filter(other, _module) do
    {:cont, other}
  end

  defp update_route_direction(td, nil, _) do
    td
  end

  defp update_route_direction(td, trip_id, module) do
    td =
      if TripDescriptor.route_id(td) do
        td
      else
        TripDescriptor.update_route_id(td, module.route_id(trip_id))
      end

    if TripDescriptor.direction_id(td) do
      td
    else
      TripDescriptor.update_direction_id(td, module.direction_id(trip_id))
    end
  end
end
