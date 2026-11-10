defmodule Concentrate.GroupFilter.Shuttle do
  @moduledoc """
  Handle shuttles by skipping StopTimeUpdates involving the shuttle.
  """
  @behaviour Concentrate.GroupFilter
  alias Concentrate.Encoder.TripGroup
  alias Concentrate.{StopTimeUpdate, TripDescriptor}

  @impl Concentrate.GroupFilter
  def filter(trip_group, shuttle_module \\ Concentrate.Filter.Alert.Shuttles)

  def filter(
        %TripGroup{td: %TripDescriptor{} = td, stus: stus} = group,
        module
      ) do
    trip_id = TripDescriptor.trip_id(td)
    route_id = TripDescriptor.route_id(td)
    direction_id = TripDescriptor.direction_id(td)
    date = TripDescriptor.start_date(td)

    stus =
      if is_tuple(date) and is_binary(route_id) and
           module.trip_shuttling?(trip_id, route_id, direction_id, date) do
        shuttle_updates(route_id, direction_id, stus, module)
      else
        stus
      end

    %{group | stus: stus}
  end

  def filter(%TripGroup{} = other, _module), do: other

  # There are three cases to consider:
  # 1. The disruption includes the first STU.
  #    In this case, we skip all STUs until the end of the disruption. The last
  #    STU within the disruption will have its arrival time dropped but its
  #    departure time will be kept. STUs after the disruption will be left
  #    unchanged.
  # 2. The disruption starts somewhere later in the route.
  #    In this case, the first STU within the disruption will have its
  #    departure time dropped but its arrival time will be kept. All STUs after
  #    the start of the disruption are skipped, including ones after the end of
  #    the disruption.
  # 3. The disruption only affects a single STU.
  #    This is the case when the disruption only affects one branch, only
  #    intersecting the other branch at a single station. In this case, the
  #    STUs, including the one affected by the disruption, will be unchanged.
  defp shuttle_updates(route_id, direction_id, stus, module) do
    stus
    |> Stream.map(&with_shuttling_status(&1, route_id, direction_id, module))
    # look at the current stop and the following stop to determine whether the disruption actually affects this trip
    |> Stream.chunk_every(2, 1, [{nil, :end_of_trip}])
    |> Enum.map_reduce(:first_stu, fn [{stu, stu_status}, {_, next_stu_status}], state ->
      do_stu_updates(stu, stu_status, next_stu_status, state)
    end)
    |> elem(0)
  end

  @spec do_stu_updates(
          stu :: StopTimeUpdate.t(),
          stu_status :: :start | :through | :stop | :stu_skipped | nil,
          next_stu_status :: :start | :through | :stop | :stu_skipped | :end_of_trip | nil,
          state :: :first_stu | :after_shuttle | :initial_shuttle | :regular_service
        ) :: {
          new_stu :: StopTimeUpdate.t(),
          new_state :: :after_shuttle | :initial_shuttle | :regular_service
        }
  defp do_stu_updates(stu, stu_status, next_stu_status, state) do
    case {stu_status, next_stu_status, state} do
      # after a shuttle on the route, all future STUs are skipped
      {_, _, :after_shuttle} ->
        {StopTimeUpdate.skip(stu), :after_shuttle}

      # if the following stop is not disrupted, then this stop is only
      # disrupted on a different branch
      {:start, status, :first_stu} when status in [nil, :end_of_trip] ->
        {stu, :regular_service}

      {:start, status, state} when status in [nil, :end_of_trip] ->
        {stu, state}

      # the start of a disruption, followed by another disrupted stop,
      # indicates that this disruption applies to this trip
      {:start, _, _} ->
        {StopTimeUpdate.update_departure_time(stu, nil), :after_shuttle}

      # if the following stop is not disrupted, then this stop is only
      # disrupted on a different branch
      {:through, nil, :first_stu} ->
        {stu, :regular_service}

      {:through, nil, state} ->
        {stu, state}

      # if the first STU is in the middle of a disruption, skip STUs within the
      # disruption, but allow STUs after the disruption to remain as they are
      {:through, _, state} when state in [:first_stu, :initial_shuttle] ->
        {StopTimeUpdate.skip(stu), :initial_shuttle}

      # at the end of a disruption, drop the arrival time
      {:stop, _, state} when state in [:first_stu, :initial_shuttle] ->
        {StopTimeUpdate.update_arrival_time(stu, nil), :regular_service}

      # if the previous stop was not disrupted, then this stop is only
      # disrupted on a different branch
      {:stop, _, state} ->
        {stu, state}

      # if this stop is not disrupted by a shuttle, leave it as it is
      {_, _, :first_stu} ->
        {stu, :regular_service}

      {_, _, state} ->
        {stu, state}
    end
  end

  @spec with_shuttling_status(
          stu :: StopTimeUpdate.t(),
          route_id :: String.t(),
          direction_id :: 0 | 1,
          module :: module()
        ) :: {
        stu :: StopTimeUpdate.t(),
        status :: :start | :through | :stop | :stu_skipped | nil
        }
  defp with_shuttling_status(stu, route_id, direction_id, module) do
    time = StopTimeUpdate.time(stu)

    if is_integer(time) do
      stop_id = StopTimeUpdate.stop_id(stu)
      {stu, module.stop_shuttling_on_route(route_id, stop_id, direction_id, time)}
    else
      {stu, :stu_skipped}
    end
  end
end
