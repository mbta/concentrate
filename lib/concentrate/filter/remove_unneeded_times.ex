defmodule Concentrate.Filter.RemoveUnneededTimes do
  @moduledoc """
  Removes arrival times from the first stop on a trip, and the departure time from the last stop on a trip.
  """
  alias Concentrate.{TripUpdate, StopTimeUpdate}
  alias Concentrate.Filter.GTFS.PickupDropOff
  @behaviour Concentrate.Filter

  @impl Concentrate.Filter
  def init do
    {PickupDropOff, MapSet.new()}
  end

  @impl Concentrate.Filter
  def filter(%TripUpdate{} = tu, {module, set}) do
    set =
      if TripUpdate.schedule_relationship(tu) == :SCHEDULED do
        set
      else
        # not a scheduled trip: we won't make any changes
        MapSet.put(set, TripUpdate.trip_id(tu))
      end

    {:cont, tu, {module, set}}
  end

  def filter(%StopTimeUpdate{} = stu, {module, set}) do
    trip_id = StopTimeUpdate.trip_id(stu)

    stu =
      if MapSet.member?(set, trip_id) do
        # not a scheduled trip: don't worry about it
        stu
      else
        ensure_correct_times(stu, module, trip_id)
      end

    {:cont, stu, {module, set}}
  end

  def filter(other, state) do
    {:cont, other, state}
  end

  defp stop_sequence_or_stop_id(stu) do
    case StopTimeUpdate.stop_sequence(stu) do
      nil ->
        StopTimeUpdate.stop_id(stu)

      sequence ->
        sequence
    end
  end

  defp ensure_correct_times(stu, module, trip_id) do
    key = stop_sequence_or_stop_id(stu)
    pickup? = module.pickup?(trip_id, key)
    drop_off? = module.drop_off?(trip_id, key)

    cond do
      pickup? and drop_off? ->
        ensure_both_times(stu)

      not (pickup? or drop_off?) ->
        StopTimeUpdate.skip(stu)

      pickup? ->
        # not drop_off?
        remove_arrival_time(stu)

      true ->
        # not pickup?
        remove_departure_time(stu)
    end
  end

  defp ensure_both_times(stu) do
    arrival_time = StopTimeUpdate.arrival_time(stu)
    departure_time = StopTimeUpdate.departure_time(stu)

    case {arrival_time, departure_time} do
      {nil, departure_time} when is_integer(departure_time) ->
        StopTimeUpdate.update_arrival_time(stu, departure_time)

      {arrival_time, nil} when is_integer(arrival_time) ->
        StopTimeUpdate.update_departure_time(stu, arrival_time)

      _ ->
        stu
    end
  end

  defp remove_arrival_time(stu) do
    if StopTimeUpdate.departure_time(stu) do
      StopTimeUpdate.update_arrival_time(stu, nil)
    else
      arrival_time = StopTimeUpdate.arrival_time(stu)
      StopTimeUpdate.update(stu, %{arrival_time: nil, departure_time: arrival_time})
    end
  end

  defp remove_departure_time(stu) do
    if StopTimeUpdate.arrival_time(stu) do
      StopTimeUpdate.update_departure_time(stu, nil)
    else
      departure_time = StopTimeUpdate.departure_time(stu)
      StopTimeUpdate.update(stu, %{departure_time: nil, arrival_time: departure_time})
    end
  end
end
