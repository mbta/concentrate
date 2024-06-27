defmodule Concentrate.GroupFilter.Shuttle do
  @moduledoc """
  Handle shuttles by skipping StopTimeUpdates involving the shuttle.
  """
  @behaviour Concentrate.GroupFilter
  alias Concentrate.{StopTimeUpdate, TripDescriptor}
  require Logger

  @impl Concentrate.GroupFilter
  def filter(trip_group, shuttle_module \\ Concentrate.Filter.Alert.Shuttles)

  def filter({%TripDescriptor{} = td, vps, stus}, module) do
    trip_id = TripDescriptor.trip_id(td)
    route_id = TripDescriptor.route_id(td)
    direction_id = TripDescriptor.direction_id(td)
    date = TripDescriptor.start_date(td)

    stus =
      if is_tuple(date) and is_binary(route_id) and
           module.trip_shuttling?(trip_id, route_id, direction_id, date) do
        shuttle_updates(route_id, stus, module)
      else
        stus
      end

    {td, vps, stus}
  end

  def filter(other, _module), do: other

  defp shuttle_updates(route_id, stus, module) do
    initial_state = {false, false}

    stus
    |> Enum.flat_map_reduce(initial_state, &shuttle_stop(route_id, module, &1, &2))
    |> elem(0)
  end

  defp shuttle_stop(route_id, shuttle_module, stop_time_updates, state)

  defp shuttle_stop(_route_id, _module, stu, {true, true} = state) do
    {[StopTimeUpdate.skip(stu)], state}
  end

  defp shuttle_stop(route_id, module, stu, {has_started?, has_shuttled?} = state) do
    time = StopTimeUpdate.time(stu)

    if is_integer(time) do
      stop_id = StopTimeUpdate.stop_id(stu)

      case module.stop_shuttling_on_route(route_id, stop_id, time) do
        nil ->
          Logger.info("modifying_shuttle_stop (nil) stu=#{inspect(stu.stop_id, limit: :infinity)}")
          drop_arrival_time_if_after_shuttle(stu, has_shuttled?)

        :through ->
          Logger.info("modifying_shuttle_stop (through) stu=#{inspect(stu.stop_id, limit: :infinity)}")
          {[StopTimeUpdate.skip(stu)], {has_started?, true}}

        :start ->
          Logger.info("modifying_shuttle_stop (start) stu=#{inspect(stu.stop_id, limit: :infinity)}")
          {[StopTimeUpdate.update_departure_time(stu, nil)], {true, true}}

        :stop ->
          Logger.info("modifying_shuttle_stop (stop) stu=#{inspect(stu.stop_id, limit: :infinity)}")
          {[StopTimeUpdate.update_arrival_time(stu, nil)], {false, false}}
      end
    else
      {[stu], state}
    end
  end

  defp drop_arrival_time_if_after_shuttle(stu, has_shuttled?)

  defp drop_arrival_time_if_after_shuttle(stu, true) do
    {[StopTimeUpdate.update_arrival_time(stu, nil)], {true, false}}
  end

  defp drop_arrival_time_if_after_shuttle(stu, has_shuttled?) do
    {[stu], {true, has_shuttled?}}
  end
end
