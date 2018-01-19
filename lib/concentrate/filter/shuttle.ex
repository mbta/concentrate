defmodule Concentrate.Filter.Shuttle do
  @moduledoc """
  Handle shuttles by skipping StopTimeUpdates involving the shuttle.
  """
  @behaviour Concentrate.Filter
  alias Concentrate.{TripUpdate, StopTimeUpdate, VehiclePosition}

  defstruct module: Concentrate.Filter.Alert.Shuttles,
            trip_to_route: %{},
            trips_with_vehicles: MapSet.new(),
            trips_being_shuttled: MapSet.new()

  @impl Concentrate.Filter
  def init do
    %__MODULE__{}
  end

  @impl Concentrate.Filter
  def filter(%TripUpdate{} = tu, _next_item, state) do
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

  def filter(%VehiclePosition{} = vp, _next_item, state) do
    trip_id = VehiclePosition.trip_id(vp)

    state =
      if Map.has_key?(state.trip_to_route, trip_id) do
        put_in(state.trips_with_vehicles, MapSet.put(state.trips_with_vehicles, trip_id))
      else
        state
      end

    {:cont, vp, state}
  end

  def filter(%StopTimeUpdate{} = stu, %StopTimeUpdate{} = next_stu, state) do
    case maybe_skip(stu, state) do
      {:skip, state} ->
        {:skip, state}

      {:cont, new_stu, state} ->
        new_stu =
          cond do
            new_stu != stu ->
              new_stu

            not Map.has_key?(state.trip_to_route, StopTimeUpdate.trip_id(new_stu)) ->
              new_stu

            match?({:cont, ^next_stu, _}, maybe_skip(next_stu, state)) ->
              # not skipping the next one either
              new_stu

            true ->
              # remove the departure time from this update
              StopTimeUpdate.update_departure_time(stu, nil)
          end

        {:cont, new_stu, state}
    end
  end

  def filter(%StopTimeUpdate{} = stu, _next_item, state) do
    maybe_skip(stu, state)
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
        is_nil(time) ->
          {:cont, stu, state}

        not MapSet.member?(state.trips_with_vehicles, trip_id) ->
          {:skip, state}

        MapSet.member?(state.trips_being_shuttled, trip_id) ->
          {:cont, StopTimeUpdate.skip(stu), state}

        state.module.stop_shuttling_on_route?(route_id, StopTimeUpdate.stop_id(stu), time) ->
          trips_being_shuttled = MapSet.put(state.trips_being_shuttled, trip_id)
          state = %{state | trips_being_shuttled: trips_being_shuttled}
          {:cont, StopTimeUpdate.skip(stu), state}

        true ->
          {:cont, stu, state}
      end
    else
      _ -> {:cont, stu, state}
    end
  end
end
