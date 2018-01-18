defmodule Concentrate.Filter.Shuttle do
  @moduledoc """
  Handle shuttles by skipping StopTimeUpdates involving the shuttle.
  """
  @behaviour Concentrate.Filter
  alias Concentrate.{TripUpdate, StopTimeUpdate}

  defstruct module: Concentrate.Filter.Alert.Shuttles,
            trip_to_route: %{},
            trips_being_shuttled: MapSet.new()

  @impl Concentrate.Filter
  def init do
    %__MODULE__{}
  end

  @impl Concentrate.Filter
  def filter(%TripUpdate{} = tu, _next_item, state) do
    route_id = TripUpdate.route_id(tu)

    state =
      if state.module.route_shuttling?(route_id, TripUpdate.start_date(tu)) do
        trip_id = TripUpdate.trip_id(tu)
        put_in(state.trip_to_route[trip_id], route_id)
      else
        state
      end

    {:cont, tu, state}
  end

  def filter(%StopTimeUpdate{} = stu, %StopTimeUpdate{} = next_stu, state) do
    {new_stu, state} = maybe_skip(stu, state)

    new_stu =
      cond do
        new_stu != stu ->
          new_stu

        not Map.has_key?(state.trip_to_route, StopTimeUpdate.trip_id(new_stu)) ->
          new_stu

        match?({^next_stu, _}, maybe_skip(next_stu, state)) ->
          # not skipping the next one either
          new_stu

        true ->
          # remove the departure time from this update
          StopTimeUpdate.update_departure_time(stu, nil)
      end

    {:cont, new_stu, state}
  end

  def filter(%StopTimeUpdate{} = stu, _next_item, state) do
    {stu, state} = maybe_skip(stu, state)
    {:cont, stu, state}
  end

  def filter(item, _next_item, state) do
    {:cont, item, state}
  end

  defp maybe_skip(%StopTimeUpdate{} = stu, state) do
    trip_id = StopTimeUpdate.trip_id(stu)

    with {:ok, route_id} <- Map.fetch(state.trip_to_route, trip_id) do
      # see if we're shuttling this particular stop
      time = StopTimeUpdate.arrival_time(stu) || StopTimeUpdate.departure_time(stu)

      cond do
        trip_id in state.trips_being_shuttled ->
          {StopTimeUpdate.skip(stu), state}

        state.module.stop_shuttling_on_route?(route_id, StopTimeUpdate.stop_id(stu), time) ->
          trips_being_shuttled = MapSet.put(state.trips_being_shuttled, trip_id)
          state = %{state | trips_being_shuttled: trips_being_shuttled}
          {StopTimeUpdate.skip(stu), state}

        true ->
          {stu, state}
      end
    else
      _ -> {stu, state}
    end
  end
end
