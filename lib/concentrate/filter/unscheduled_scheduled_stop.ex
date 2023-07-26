defmodule Concentrate.Filter.UnscheduledScheduledStop do
  @moduledoc """
  Filters out StopTimeUpdates with a null arrival and departure time but a schedule_relationship of scheduled.
  """
  @behaviour Concentrate.Filter
  alias Concentrate.StopTimeUpdate
  require Logger

  @impl Concentrate.Filter
  def filter(%StopTimeUpdate{} = stu) do
    if !StopTimeUpdate.arrival_time(stu) && !StopTimeUpdate.departure_time(stu) &&
         (StopTimeUpdate.schedule_relationship(stu) == :SCHEDULED ||
            !StopTimeUpdate.schedule_relationship(stu)) do
      Logger.warning(
        "event=unscheduled_scheduled_stop trip_id=#{stu.trip_id} stop_sequence=#{stu.stop_sequence} schedule_relationship=#{stu.schedule_relationship} status=#{stu.status} stu=#{inspect(stu)}"
      )

      :skip
    else
      {:cont, stu}
    end
  end

  def filter(other), do: {:cont, other}
end
