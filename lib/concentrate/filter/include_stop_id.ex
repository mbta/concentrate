defmodule Concentrate.Filter.IncludeStopID do
  @moduledoc """
  Adds stop ID for StopTimeUpdates.
  """
  @behaviour Concentrate.Filter
  alias Concentrate.Filter.GTFS.StopIDs
  alias Concentrate.StopTimeUpdate

  @impl Concentrate.Filter
  def filter(item, module \\ StopIDs)

  def filter(%StopTimeUpdate{} = stu, module) do
    trip_id = StopTimeUpdate.trip_id(stu)
    stop_sequence = StopTimeUpdate.stop_sequence(stu)
    stop_id = StopTimeUpdate.stop_id(stu)
    stu = update_stop_id(stu, stop_id, trip_id, stop_sequence, module)
    {:cont, stu}
  end

  def filter(other, _module) do
    {:cont, other}
  end

  defp update_stop_id(stu, nil, trip_id, stop_sequence, module)
       when is_binary(trip_id) and is_integer(stop_sequence) do
    case module.stop_id(trip_id, stop_sequence) do
      stop_id when is_binary(stop_id) ->
        StopTimeUpdate.update_stop_id(stu, stop_id)

      _ ->
        stu
    end
  end

  defp update_stop_id(stu, _, _, _, _) do
    stu
  end
end
