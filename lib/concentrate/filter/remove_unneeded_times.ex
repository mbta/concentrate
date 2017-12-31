defmodule Concentrate.Filter.RemoveUnneededTimes do
  @moduledoc """
  Removes arrival times from the first stop on a trip, and the departure time from the last stop on a trip.
  """
  alias Concentrate.StopTimeUpdate
  alias Concentrate.Filter.GTFS.PickupDropOff
  @behaviour Concentrate.Filter

  @impl Concentrate.Filter
  def init do
    {:parallel, PickupDropOff}
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

    pickup? = module.pickup?(trip_id, stop_sequence)
    drop_off? = module.drop_off?(trip_id, stop_sequence)

    stu =
      cond do
        pickup? and drop_off? ->
          stu

        not (pickup? or drop_off?) ->
          StopTimeUpdate.skip(stu)

        pickup? ->
          # not drop_off?
          remove_arrival_time(stu)

        true ->
          # not pickup?
          remove_departure_time(stu)
      end

    {:cont, stu, module}
  end

  def filter(other, module) do
    {:cont, other, module}
  end

  defp remove_arrival_time(stu) do
    if StopTimeUpdate.departure_time(stu) do
      StopTimeUpdate.update(stu, arrival_time: nil)
    else
      arrival_time = StopTimeUpdate.arrival_time(stu)
      StopTimeUpdate.update(stu, arrival_time: nil, departure_time: arrival_time)
    end
  end

  defp remove_departure_time(stu) do
    if StopTimeUpdate.arrival_time(stu) do
      StopTimeUpdate.update(stu, departure_time: nil)
    else
      departure_time = StopTimeUpdate.departure_time(stu)
      StopTimeUpdate.update(stu, departure_time: nil, arrival_time: departure_time)
    end
  end
end
