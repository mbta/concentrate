defmodule Concentrate.GTFS.FakeTrips do
  @moduledoc "Fake implementation of GTFS.Trips"
  def route_id("trip"), do: "route"
  def route_id(_), do: nil

  def direction_id("trip"), do: 1
  def direction_id(_), do: nil
end

defmodule Concentrate.Filter.FakeCancelledTrips do
  @moduledoc "Fake implementation of Filter.Alerts.CancelledTrips"
  def route_cancelled?("route", {1970, 1, 2}) do
    true
  end

  def route_cancelled?("route", unix) do
    unix > 86_405 and unix < 86_410
  end

  def route_cancelled?(route, time) when is_binary(route) and is_integer(time) do
    false
  end

  def route_cancelled?(route, {_, _, _}) when is_binary(route) do
    false
  end

  def trip_cancelled?("trip", {1970, 1, 1}) do
    true
  end

  def trip_cancelled?("trip", unix) do
    unix > 5 and unix < 10
  end

  def trip_cancelled?(trip, time) when is_binary(trip) and is_integer(time) do
    false
  end

  def trip_cancelled?(trip, {_, _, _}) when is_binary(trip) do
    false
  end
end

defmodule Concentrate.Filter.FakeClosedStops do
  @moduledoc "Fake implementation of Filter.Alerts.ClosedStops"
  alias Concentrate.Alert.InformedEntity

  def stop_closed_for("stop", unix) do
    cond do
      unix < 5 ->
        []

      unix > 10 ->
        []

      true ->
        [
          InformedEntity.new(trip_id: "trip", route_id: "route")
        ]
    end
  end

  def stop_closed_for("route_stop", _) do
    [
      InformedEntity.new(route_id: "other_route")
    ]
  end

  def stop_closed_for(_, _) do
    []
  end
end

defmodule Concentrate.Filter.FakeShuttles do
  @moduledoc "Fake implementation of Filter.Alerts.Shuttles"

  def trip_shuttling?("trip", "route", _, {1970, 1, 1}), do: true
  def trip_shuttling?("trip", "single_direction", 0, {1970, 1, 1}), do: true
  def trip_shuttling?(_trip_id, _route_id, _direction_id, {_, _, _}), do: false

  def stop_shuttling_on_route("route", "shuttle_1", 8), do: :through
  def stop_shuttling_on_route("route", "shuttle_2", 8), do: :through
  def stop_shuttling_on_route("route", "shuttle_start", 8), do: :start
  def stop_shuttling_on_route("route", "shuttle_stop", 8), do: :stop
  def stop_shuttling_on_route("single_direction", "shuttle_1", 8), do: :through
  def stop_shuttling_on_route(_, _, dt) when is_integer(dt), do: nil
end
