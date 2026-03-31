defmodule Concentrate.GroupFilter.SkippedStopOnAddedTrip do
  @moduledoc """
  Removes SKIPPED stops from ADDED/UNSCHEDULED trips.
  """
  @behaviour Concentrate.GroupFilter
  alias Concentrate.Encoder.TripGroup
  alias Concentrate.{StopTimeUpdate, TripDescriptor}

  @impl Concentrate.GroupFilter
  def filter(%TripGroup{td: %TripDescriptor{} = td, stus: stus} = group) do
    stus =
      if TripDescriptor.schedule_relationship(td) in ~w(ADDED UNSCHEDULED)a do
        Enum.reject(
          stus,
          &(StopTimeUpdate.schedule_relationship(&1) == :SKIPPED &&
              StopTimeUpdate.passthrough_time(&1) == nil)
        )
      else
        stus
      end

    %{group | td: td, stus: stus}
  end

  def filter(%TripGroup{} = other), do: other
end
