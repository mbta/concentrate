defmodule Concentrate.Filter.CancelledTrip do
  @moduledoc """
  Cancels TripUpdates and skips StopTimeUpdates for cancelled trips.
  """
  @behaviour Concentrate.Filter
  alias Concentrate.{TripUpdate, StopTimeUpdate}
  alias Concentrate.Filter.Alert.CancelledTrips

  @impl Concentrate.Filter
  def init do
    CancelledTrips
  end

  @impl Concentrate.Filter
  def filter(%StopTimeUpdate{} = stu, module) do
    time = StopTimeUpdate.arrival_time(stu) || StopTimeUpdate.departure_time(stu)

    stu =
      cond do
        is_nil(time) ->
          stu

        module.trip_cancelled?(StopTimeUpdate.trip_id(stu), time) ->
          StopTimeUpdate.skip(stu)

        true ->
          stu
      end

    {:cont, stu, module}
  end

  def filter(%TripUpdate{} = tu, module) do
    tu =
      if module.trip_cancelled?(TripUpdate.trip_id(tu), TripUpdate.start_date(tu)) do
        # single L
        TripUpdate.update(tu, schedule_relationship: :CANCELED)
      else
        tu
      end

    {:cont, tu, module}
  end

  def filter(other, modules) do
    {:cont, other, modules}
  end
end
