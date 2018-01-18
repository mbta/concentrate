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

  def filter(%StopTimeUpdate{} = stu, state) do
    trip_id = StopTimeUpdate.trip_id(stu)

    {stu, state} =
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

    {:cont, stu, state}
  end

  def filter(item, state) do
    {:cont, item, state}
  end
end
