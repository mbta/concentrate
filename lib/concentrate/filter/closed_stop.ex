defmodule Concentrate.Filter.ClosedStop do
  @moduledoc """
  Skips StopTimeUpdates for closed stops.
  """
  @behaviour Concentrate.Filter
  alias Concentrate.{StopTimeUpdate, Alert.InformedEntity}
  alias Concentrate.Filter.Alert.ClosedStops
  alias Concentrate.Filter.GTFS.Trips

  @modules {ClosedStops, Trips}

  @impl Concentrate.Filter
  def filter(update, modules \\ @modules)

  def filter(%StopTimeUpdate{} = stu, {stops_module, trips_module}) do
    time = StopTimeUpdate.time(stu)

    stu =
      if is_integer(time) do
        entities = stops_module.stop_closed_for(StopTimeUpdate.stop_id(stu), time)
        update_stu_from_closed_entities(stu, entities, trips_module)
      else
        stu
      end

    {:cont, stu}
  end

  def filter(other, _modules) do
    {:cont, other}
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
      StopTimeUpdate.skip(stu)
    else
      stu
    end
  end
end
