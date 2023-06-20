defmodule Concentrate.GroupFilter.TimeTravel do
  @moduledoc """
  Drops StopTimeUpdates that predict arriving at a later stop before departing an earlier one..
  """
  require Logger

  @behaviour Concentrate.GroupFilter
  @impl Concentrate.GroupFilter

  def filter({td, vps, stop_time_updates}) do
    stop_time_updates =
      stop_time_updates
      |> Enum.reduce([], &filter_stop_time_update/2)
      |> Enum.reverse()

    {td, vps, stop_time_updates}
  end

  defp filter_stop_time_update(stop_time_update, []) do
    [stop_time_update]
  end

  defp filter_stop_time_update(stop_time_update, [prev | _] = stop_time_updates) do
    prev_time = prev.departure_time || prev.arrival_time
    time = stop_time_update.arrival_time || stop_time_update.departure_time

    if not is_nil(prev_time) and time < prev_time do
      Logger.warning(
        "event=time_travel trip_id=#{stop_time_update.trip_id} prev_stop=#{prev.stop_sequence} prev_time=#{prev_time} stop=#{stop_time_update.stop_sequence} time=#{time}"
      )

      [stop_time_update]
    else
      [stop_time_update | stop_time_updates]
    end
  end
end
