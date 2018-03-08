defmodule Concentrate.GroupFilter.Shuttle do
  @moduledoc """
  Handle shuttles by skipping StopTimeUpdates involving the shuttle.
  """
  @behaviour Concentrate.GroupFilter
  alias Concentrate.{TripUpdate, StopTimeUpdate}

  @impl Concentrate.GroupFilter
  def filter(trip_group, shuttle_module \\ Concentrate.Filter.Alert.Shuttles)

  def filter({%TripUpdate{} = tu, vps, stus}, module) do
    trip_id = TripUpdate.trip_id(tu)
    route_id = TripUpdate.route_id(tu)
    direction_id = TripUpdate.direction_id(tu)
    date = TripUpdate.start_date(tu)

    stus =
      if is_tuple(date) and is_binary(route_id) and
           module.trip_shuttling?(trip_id, route_id, direction_id, date) do
        shuttle_updates(route_id, stus, module)
      else
        stus
      end

    {tu, vps, stus}
  end

  def filter(other, _module), do: other

  defp shuttle_updates(route_id, stus, module) do
    {stus, _} = Enum.flat_map_reduce(stus, false, &shuttle_stop(route_id, module, &1, &2))
    stus
  end

  defp shuttle_stop(route_id, shuttle_module, stop_time_updates, has_shuttled?)

  defp shuttle_stop(_route_id, _module, stu, true) do
    {[StopTimeUpdate.skip(stu)], true}
  end

  defp shuttle_stop(route_id, module, stu, false) do
    time = StopTimeUpdate.arrival_time(stu) || StopTimeUpdate.departure_time(stu)
    stop_id = StopTimeUpdate.stop_id(stu)

    if is_integer(time) and module.stop_shuttling_on_route?(route_id, stop_id, time) do
      {[StopTimeUpdate.skip(stu)], true}
    else
      {[stu], false}
    end
  end
end
