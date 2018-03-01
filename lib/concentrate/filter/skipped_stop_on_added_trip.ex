defmodule Concentrate.Filter.SkippedStopOnAddedTrip do
  @moduledoc """
  Removes SKIPPED StopTimeUpdates from ADDED trips.
  """
  @behaviour Concentrate.Filter
  alias Concentrate.{TripUpdate, StopTimeUpdate}

  defstruct added_trips: MapSet.new()

  @impl Concentrate.Filter
  def init do
    %__MODULE__{}
  end

  @impl Concentrate.Filter
  def filter(%TripUpdate{} = tu, state) do
    state =
      if TripUpdate.schedule_relationship(tu) in ~w(ADDED UNSCHEDULED)a do
        update_in(state.added_trips, &MapSet.put(&1, TripUpdate.trip_id(tu)))
      else
        state
      end

    {:cont, tu, state}
  end

  def filter(%StopTimeUpdate{} = stu, %{added_trips: added_trips} = state) do
    cond do
      StopTimeUpdate.schedule_relationship(stu) != :SKIPPED ->
        {:cont, stu, state}

      not MapSet.member?(added_trips, StopTimeUpdate.trip_id(stu)) ->
        {:cont, stu, state}

      true ->
        {:skip, state}
    end
  end

  def filter(item, state) do
    {:cont, item, state}
  end
end
