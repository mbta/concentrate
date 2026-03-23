defmodule Concentrate.Filter.AssignedStopID do
  @moduledoc """
  Reject assigned_stop_id field in StopTimeUpdates if it's the same as the scheduled stop id.
  """
  @behaviour Concentrate.Filter
  alias Concentrate.GTFS.StopTimes
  alias Concentrate.StopTimeUpdate

  @impl Concentrate.Filter
  def filter(item, stop_times \\ StopTimes)

  def filter(%StopTimeUpdate{} = stu, stop_times) do
    {:cont,
     maybe_filter_assigned_stop_id(
       stu,
       StopTimeUpdate.assigned_stop_id(stu),
       StopTimeUpdate.trip_id(stu),
       StopTimeUpdate.stop_sequence(stu),
       stop_times
     )}
  end

  def filter(other, _stop_ids), do: {:cont, other}

  defp maybe_filter_assigned_stop_id(stu, nil, _, _, _), do: stu

  defp maybe_filter_assigned_stop_id(stu, assigned_stop_id, trip_id, stop_sequence, stop_times)
       when is_binary(trip_id) and is_integer(stop_sequence) do
    case stop_times.stop_id(trip_id, stop_sequence) do
      :unknown ->
        stu

      stop_id ->
        # the scheduled stop id matches the assigned_stop_id field so no need to publish it
        if stop_id == assigned_stop_id,
          do: StopTimeUpdate.update_assigned_stop_id(stu, nil),
          else: stu
    end
  end

  defp maybe_filter_assigned_stop_id(stu, _, _, _, _), do: stu
end
