defmodule Concentrate.Reporter.UnskippedNullStops do
  @moduledoc """
  Logs StopTimeUpdates that lack arrival and departure times, but aren't skipped.
  """
  require Logger

  alias Concentrate.StopTimeUpdate

  @behaviour Concentrate.Reporter
  @impl Concentrate.Reporter

  def init do
    []
  end

  def level, do: :warning

  @impl Concentrate.Reporter
  def log(groups, _) do
    Enum.each(groups, &log_group/1)
    {[], []}
  end

  def log_group({_td, _vps, stop_time_updates}) do
    Enum.each(stop_time_updates, &stu_check/1)

    []
  end

  defp stu_check(
         %StopTimeUpdate{
           arrival_time: arrival_time,
           departure_time: departure_time,
           schedule_relationship: schedule_relationship
         } = stu
       ) do
    if !arrival_time && !departure_time && schedule_relationship !== :SKIPPED do
      Logger.warning(
        "event=unskipped_null_stop trip_id=#{stu.trip_id} stop_sequence=#{stu.stop_sequence} stu=#{inspect(stu)}"
      )
    end
  end
end
