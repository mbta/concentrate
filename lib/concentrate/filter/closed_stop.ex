defmodule Concentrate.Filter.ClosedStop do
  @moduledoc """
  Skips StopTimeUpdates for closed stops.
  """
  @behaviour Concentrate.Filter
  alias Concentrate.{StopTimeUpdate, Alert.InformedEntity}
  alias Concentrate.Filter.Alert.ClosedStops
  alias Concentrate.Filter.GTFS.Trips

  def init do
    {:parallel, {ClosedStops, Trips}}
  end

  def filter(%StopTimeUpdate{} = stu, {stops_module, trips_module} = modules) do
    time = StopTimeUpdate.arrival_time(stu) || StopTimeUpdate.departure_time(stu)
    entities = stops_module.stop_closed_for(StopTimeUpdate.stop_id(stu), time)
    stu = update_stu_from_closed_entities(stu, entities, trips_module)
    {:cont, stu, modules}
  end

  def filter(other, modules) do
    {:cont, other, modules}
  end

  defp update_stu_from_closed_entities(stu, [], _) do
    stu
  end

  defp update_stu_from_closed_entities(stu, entities, trips_module) do
    trip_id = StopTimeUpdate.trip_id(stu)

    match = [
      trip_id: trip_id,
      route_id: trips_module.route_id(trip_id),
      direction_id: trips_module.direction_id(trip_id)
    ]

    if Enum.any?(entities, &InformedEntity.match?(&1, match)) do
      StopTimeUpdate.update(stu, schedule_relationship: :SKIPPED)
    else
      stu
    end
  end
end
