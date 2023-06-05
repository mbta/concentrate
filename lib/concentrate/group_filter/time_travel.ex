defmodule Concentrate.GroupFilter.TimeTravel do
  @moduledoc """
  Drops StopTimeUpdates that predict arriving at a later stop before departing an earlier one..
  """
  require Logger

  @behaviour Concentrate.GroupFilter
  @impl Concentrate.GroupFilter

  def filter({td, vps, stus}) do
    stus =
      stus
      |> Enum.reduce([], &filter_stu/2)
      |> Enum.reverse()

    {td, vps, stus}
  end

  defp filter_stu(stu, []) do
    [stu]
  end

  defp filter_stu(stu, [prev | _] = stus) do
    prev_time = prev.departure_time || prev.arrival_time
    time = stu.arrival_time || stu.departure_time

    if time < prev_time do
      Logger.warning("""
      Trip ID: #{stu.trip_id} predicts arriving at stop #{stu.stop_sequence} at #{time}
      before departing stop #{prev.stop_sequence} at #{prev_time}. Dropping prior predictions.
      """)

      [stu]
    else
      [stu | stus]
    end
  end
end
