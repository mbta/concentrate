defmodule Concentrate.Reporter.TimeTravel do
  @moduledoc """
  Drops StopTimeUpdates that predict arriving at a later stop before departing an earlier one..
  """
  require Logger

  @behaviour Concentrate.Reporter

  @impl Concentrate.Reporter
  def init do
    []
  end

  @impl Concentrate.Reporter
  def log(groups, _) do
    Enum.each(groups, &log_group/1)
    {[], []}
  end

  defp log_group({_td, _vps, stop_time_updates}) do
    time_travel_check(stop_time_updates)

    []
  end

  defp time_travel_check([first, second | rest]) do
    first_time = first.departure_time || first.arrival_time
    second_time = second.arrival_time || second.departure_time

    if first_time && second_time && second_time < first_time do
      Logger.warning(
        "event=time_travel trip_id=#{first.trip_id} first_stop=#{first.stop_sequence} first_time=#{first_time} second_stop=#{second.stop_sequence} second_time=#{second_time}"
      )
    end

    time_travel_check([second | rest])
  end

  defp time_travel_check(_) do
    nil
  end
end
