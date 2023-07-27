defmodule Concentrate.Filter.UnscheduledScheduledStop do
  @moduledoc """
  Filters out StopTimeUpdates with a null arrival and departure time but a schedule_relationship of scheduled.
  """
  @behaviour Concentrate.Filter
  alias Concentrate.StopTimeUpdate
  require Logger

  @impl Concentrate.Filter
  def filter(%StopTimeUpdate{} = stu) do
    scheduled? =
      StopTimeUpdate.schedule_relationship(stu) == :SCHEDULED ||
        StopTimeUpdate.schedule_relationship(stu) == nil

    if StopTimeUpdate.arrival_time(stu) || StopTimeUpdate.departure_time(stu) ||
         StopTimeUpdate.status(stu) ||
         !scheduled? do
      {:cont, stu}
    else
      :skip
    end
  end

  def filter(other), do: {:cont, other}
end
