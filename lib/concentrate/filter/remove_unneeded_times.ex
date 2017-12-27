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
    stop_sequences = module.stop_sequences(StopTimeUpdate.trip_id(stu))
    stu = update_stu_with_stop_sequences(stu, stop_sequences)

    {:cont, stu, module}
  end

  def filter(other, module) do
    {:cont, other, module}
  end

  defp update_stu_with_stop_sequences(stu, {first, last}) do
    stop_sequence = StopTimeUpdate.stop_sequence(stu)

    if stop_sequence in [first, last] do
      StopTimeUpdate.update(stu, stu_times_update(stu, stop_sequence, first, last))
    else
      stu
    end
  end

  defp update_stu_with_stop_sequences(stu, nil) do
    stu
  end

  defp stu_times_update(stu, first, first, _last) do
    if StopTimeUpdate.departure_time(stu) do
      [arrival_time: nil]
    else
      arrival_time = StopTimeUpdate.arrival_time(stu)
      [arrival_time: nil, departure_time: arrival_time]
    end
  end

  defp stu_times_update(stu, last, _first, last) do
    if StopTimeUpdate.arrival_time(stu) do
      [departure_time: nil]
    else
      departure_time = StopTimeUpdate.departure_time(stu)
      [arrival_time: departure_time, departure_time: nil]
    end
  end
end
