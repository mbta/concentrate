defmodule Concentrate.Filter.CancelledTrip do
  @moduledoc """
  Cancels TripUpdates and skips StopTimeUpdates for cancelled trips.
  """
  @behaviour Concentrate.Filter
  alias Concentrate.{TripUpdate, StopTimeUpdate}
  alias Concentrate.Filter.Alert.CancelledTrips

  @impl Concentrate.Filter
  def init do
    {CancelledTrips, %{}}
  end

  @impl Concentrate.Filter
  def filter(%StopTimeUpdate{} = stu, {module, map}) do
    time = StopTimeUpdate.time(stu)
    trip_id = StopTimeUpdate.trip_id(stu)

    stu =
      cond do
        is_nil(time) ->
          stu

        is_binary(trip_id) and module.trip_cancelled?(trip_id, time) ->
          StopTimeUpdate.skip(stu)

        is_binary(route_id = Map.get(map, trip_id)) and module.route_cancelled?(route_id, time) ->
          StopTimeUpdate.skip(stu)

        true ->
          stu
      end

    {:cont, stu, {module, map}}
  end

  def filter(%TripUpdate{} = tu, {module, map}) do
    trip_id = TripUpdate.trip_id(tu)
    start_date = TripUpdate.start_date(tu)
    route_id = TripUpdate.route_id(tu)

    {tu, map} =
      cond do
        is_nil(start_date) ->
          {tu, map}

        is_binary(trip_id) and module.trip_cancelled?(trip_id, start_date) ->
          {TripUpdate.cancel(tu), map}

        is_binary(route_id) and module.route_cancelled?(route_id, start_date) ->
          {TripUpdate.cancel(tu), Map.put(map, trip_id, route_id)}

        true ->
          {tu, map}
      end

    {:cont, tu, {module, map}}
  end

  def filter(other, modules) do
    {:cont, other, modules}
  end
end
