defmodule Concentrate.Filter.TimeOutOfRange do
  @moduledoc """
  Rejects StopTimeUpdates which are too far in the future or in the past.
  """
  alias Concentrate.StopTimeUpdate
  @behaviour Concentrate.Filter

  # one minute
  @min_time_in_past 60
  # 3 hours
  @max_time_in_future 10_800

  @impl Concentrate.Filter
  def init do
    now = System.system_time(:second)
    {now - @min_time_in_past, now + @max_time_in_future, MapSet.new()}
  end

  @impl Concentrate.Filter
  def filter(%StopTimeUpdate{} = stu, {min_time, max_time, included_trips} = state) do
    time = StopTimeUpdate.time(stu)
    trip_id = StopTimeUpdate.trip_id(stu)

    cond do
      is_binary(trip_id) and MapSet.member?(included_trips, trip_id) ->
        {:cont, stu, state}

      is_nil(time) ->
        {:cont, stu, state}

      time > max_time ->
        {:skip, state}

      time < min_time ->
        {:skip, state}

      true ->
        {:cont, stu, {min_time, max_time, MapSet.put(included_trips, trip_id)}}
    end
  end

  def filter(other, state) do
    {:cont, other, state}
  end
end
