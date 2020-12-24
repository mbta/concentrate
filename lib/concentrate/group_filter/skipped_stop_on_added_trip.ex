defmodule Concentrate.GroupFilter.SkippedStopOnAddedTrip do
  @moduledoc """
  Removes SKIPPED stops from ADDED/UNSCHEDULED trips.
  """
  @behaviour Concentrate.GroupFilter
  alias Concentrate.{StopTimeUpdate, TripDescriptor}

  @impl Concentrate.GroupFilter
  def filter({%TripDescriptor{} = td, vps, stus}) do
    stus =
      if TripDescriptor.schedule_relationship(td) in ~w(ADDED UNSCHEDULED)a do
        Enum.reject(stus, &(StopTimeUpdate.schedule_relationship(&1) == :SKIPPED))
      else
        stus
      end

    {td, vps, stus}
  end

  def filter(other), do: other
end
