defmodule Concentrate.GroupFilter.ClosedStop do
  @moduledoc """
  Skips StopTimeUpdates for closed stops.
  """
  @behaviour Concentrate.GroupFilter
  alias Concentrate.Alert.InformedEntity
  alias Concentrate.Encoder.TripGroup
  alias Concentrate.Filter.Alert.ClosedStops
  alias Concentrate.{StopTimeUpdate, TripDescriptor}

  @impl Concentrate.GroupFilter
  def filter(trip_group, stops_module \\ ClosedStops)

  def filter(%TripGroup{td: %TripDescriptor{} = td, stus: stus} = group, stops_module) do
    route_id = TripDescriptor.route_id(td)

    match = [
      trip_id: TripDescriptor.trip_id(td),
      route_id: route_id,
      direction_id: TripDescriptor.direction_id(td)
    ]

    stus =
      for stu <- stus do
        time = StopTimeUpdate.time(stu)

        if is_integer(time) do
          entities = stops_module.stop_closed_for(StopTimeUpdate.stop_id(stu), route_id, time)
          update_stu_from_closed_entities(stu, match, entities)
        else
          stu
        end
      end

    %{group | stus: stus}
  end

  def filter(%TripGroup{} = group, _) do
    group
  end

  defp update_stu_from_closed_entities(stu, _, []) do
    stu
  end

  defp update_stu_from_closed_entities(stu, match, entities) do
    if Enum.any?(entities, &InformedEntity.match?(&1, match)) do
      StopTimeUpdate.skip(stu)
    else
      stu
    end
  end
end
