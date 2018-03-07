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
  def filter(%TripUpdate{} = tu, state) do
    trip_id = TripUpdate.trip_id(tu)
    route_id = TripUpdate.route_id(tu)
    date = TripUpdate.start_date(tu)

    state =
      cond do
        is_nil(date) ->
          state

        is_nil(route_id) ->
          state

        state.module.trip_shuttling?(trip_id, route_id, TripUpdate.direction_id(tu), date) ->
          put_in(state.trip_to_route[trip_id], route_id)

        true ->
          state
      end

    {:cont, tu, state}
  end

  def filter(%StopTimeUpdate{} = stu, state) do
    {new_stu, state} = maybe_skip(stu, state)

    {:cont, new_stu, state}
  end

  def filter(item, state) do
    {:cont, item, state}
  end

  defp maybe_skip(%StopTimeUpdate{} = stu, state) do
    trip_id = StopTimeUpdate.trip_id(stu)

    with {:ok, route_id} <- Map.fetch(state.trip_to_route, trip_id) do
      # see if we're shuttling this particular stop
      time = StopTimeUpdate.arrival_time(stu) || StopTimeUpdate.departure_time(stu)

      cond do
        is_nil(time) ->
          {stu, state}

        MapSet.member?(state.trips_being_shuttled, trip_id) ->
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
