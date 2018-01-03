defmodule Concentrate.Filter.VehiclePastStop do
  @moduledoc """
  Removes stop times if there's a vehicle on the trip that's already left the stop.
  """
  @behaviour Concentrate.Filter
  alias Concentrate.{VehiclePosition, StopTimeUpdate}

  @impl Concentrate.Filter
  def init do
    %{}
  end

  @impl Concentrate.Filter
  def filter(%VehiclePosition{} = vp, last_stops) do
    stop_sequence = VehiclePosition.stop_sequence(vp)
    trip_id = VehiclePosition.trip_id(vp)

    last_stops =
      if is_binary(trip_id) and is_integer(stop_sequence) do
        Map.put(last_stops, trip_id, stop_sequence)
      else
        last_stops
      end

    {:cont, vp, last_stops}
  end

  def filter(%StopTimeUpdate{} = stu, last_stops) do
    trip_id = StopTimeUpdate.trip_id(stu)
    last_stop = Map.get(last_stops, trip_id, 0)

    if last_stop > StopTimeUpdate.stop_sequence(stu) do
      {:skip, last_stops}
    else
      {:cont, stu, last_stops}
    end
  end

  def filter(other, last_stops) do
    {:cont, other, last_stops}
  end
end
