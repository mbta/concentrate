defmodule Concentrate.GroupFilter.ClosedStop do
  @moduledoc """
  Skips StopTimeUpdates for closed stops.
  """
  @behaviour Concentrate.GroupFilter
  alias Concentrate.{Alert.InformedEntity, StopTimeUpdate, TripDescriptor}
  alias Concentrate.Filter.Alert.ClosedStops

  @impl Concentrate.GroupFilter
  def filter(update, stops_module \\ ClosedStops)

  def filter({%TripDescriptor{} = td, vps, stus}, stops_module) do
    match = [
      trip_id: TripDescriptor.trip_id(td),
      route_id: TripDescriptor.route_id(td),
      direction_id: TripDescriptor.direction_id(td)
    ]

    stus =
      for stu <- stus do
        time = StopTimeUpdate.time(stu)

        if is_integer(time) do
          entities = stops_module.stop_closed_for(StopTimeUpdate.stop_id(stu), time)
          update_stu_from_closed_entities(stu, match, entities)
        else
          stu
        end
      end

    {td, vps, stus}
  end

  def filter({_, _, _} = group, _) do
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
