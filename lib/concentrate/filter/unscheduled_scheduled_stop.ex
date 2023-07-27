defmodule Concentrate.Filter.UnscheduledScheduledStop do
  @moduledoc """
  Filters out StopTimeUpdates with a null arrival and departure time but a schedule_relationship of scheduled.
  """
  @behaviour Concentrate.Filter
  alias Concentrate.StopTimeUpdate
  require Logger

  @impl Concentrate.Filter
  def filter(%StopTimeUpdate{} = stu) do
    if StopTimeUpdate.arrival_time(stu) || StopTimeUpdate.departure_time(stu) ||
         StopTimeUpdate.status(stu) || StopTimeUpdate.schedule_relationship(stu) !== :SCHEDULED do
      {:cont, stu}
    else
      :skip
    end
  end

  def filter(other), do: {:cont, other}
end
