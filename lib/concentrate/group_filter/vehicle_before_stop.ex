defmodule Concentrate.GroupFilter.VehicleBeforeStop do
  @moduledoc """
  Adds a historic StopTimeUpdate for the trip if the vehicle hasn't moved past it yet.
  """
  @behaviour Concentrate.GroupFilter
  alias Concentrate.TripUpdate
  alias Concentrate.GroupFilter.Cache.VehicleBeforeStop, as: Cache

  @impl Concentrate.GroupFilter
  def filter({%TripUpdate{} = tu, [vp], stus}) do
    stus = Cache.stop_time_updates_for_vehicle(vp, stus)

    {tu, [vp], stus}
  end

  def filter(other), do: other
end
