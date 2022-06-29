defmodule Concentrate.Filter.IncludeStopID do
  @moduledoc """
  Adds missing stop IDs to StopTimeUpdates.
  """
  @behaviour Concentrate.Filter
  alias Concentrate.GTFS.StopTimes
  alias Concentrate.StopTimeUpdate

  @impl Concentrate.Filter
  def filter(item, stop_times \\ StopTimes)

  def filter(%StopTimeUpdate{} = stu, stop_times) do
    {:cont,
     maybe_add_stop_id(
       stu,
       StopTimeUpdate.stop_id(stu),
       StopTimeUpdate.trip_id(stu),
       StopTimeUpdate.stop_sequence(stu),
       stop_times
     )}
  end

  def filter(other, _stop_ids), do: {:cont, other}

  defp maybe_add_stop_id(stu, nil, trip_id, stop_sequence, stop_times)
       when is_binary(trip_id) and is_integer(stop_sequence) do
    case stop_times.stop_id(trip_id, stop_sequence) do
      :unknown -> stu
      stop_id -> StopTimeUpdate.update_stop_id(stu, stop_id)
    end
  end

  defp maybe_add_stop_id(stu, _, _, _, _), do: stu
end
