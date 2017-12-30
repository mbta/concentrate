defmodule Concentrate.Filter.RemoveUnneededTimes do
  @moduledoc """
  Removes arrival times from the first stop on a trip, and the departure time from the last stop on a trip.
  """
  alias Concentrate.StopTimeUpdate
  alias Concentrate.Filter.GTFS.FirstLastStopSequence
  @behaviour Concentrate.Filter

  @impl Concentrate.Filter
  def init do
    {:parallel, FirstLastStopSequence}
  end

  @impl Concentrate.Filter
  def filter(%StopTimeUpdate{} = stu, module) do
    trip_id = StopTimeUpdate.trip_id(stu)

    stop_sequence =
      case StopTimeUpdate.stop_sequence(stu) do
        nil ->
          StopTimeUpdate.stop_id(stu)

        sequence ->
          sequence
      end

    stu =
      stu
      |> update_arrival_time(module.drop_off?(trip_id, stop_sequence))
      |> update_departure_time(module.pickup?(trip_id, stop_sequence))

    {:cont, stu, module}
  end

  def filter(other, module) do
    {:cont, other, module}
  end

  defp update_arrival_time(stu, true) do
    stu
  end

  defp update_arrival_time(stu, false) do
    if StopTimeUpdate.departure_time(stu) do
      StopTimeUpdate.update(stu, arrival_time: nil)
    else
      arrival_time = StopTimeUpdate.arrival_time(stu)
      StopTimeUpdate.update(stu, arrival_time: nil, departure_time: arrival_time)
    end
  end

  defp update_departure_time(stu, true) do
    stu
  end

  defp update_departure_time(stu, false) do
    if StopTimeUpdate.arrival_time(stu) do
      StopTimeUpdate.update(stu, departure_time: nil)
    else
      departure_time = StopTimeUpdate.departure_time(stu)
      StopTimeUpdate.update(stu, departure_time: nil, arrival_time: departure_time)
    end
  end
end
