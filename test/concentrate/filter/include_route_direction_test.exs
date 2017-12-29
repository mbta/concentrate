defmodule Concentrate.Filter.IncludeRouteDirectionTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Filter.IncludeRouteDirection
  alias Concentrate.TripUpdate

  @state Concentrate.Filter.FakeTrips

  describe "filter/2" do
    test "a trip update with a route/direction is kept as-is" do
      tu = TripUpdate.new(trip_id: "trip", route_id: "r", direction_id: 0)
      assert {:cont, ^tu, _} = filter(tu, @state)
    end

    test "a trip update without a trip is kept as-is" do
      tu = TripUpdate.new([])
      assert {:cont, ^tu, _} = filter(tu, @state)
    end

    test "a missing route/direction_id is updated" do
      tu = TripUpdate.new(trip_id: "trip")
      assert {:cont, new_tu, _} = filter(tu, @state)
      assert TripUpdate.route_id(new_tu) == "route"
      assert TripUpdate.direction_id(new_tu) == 1
    end

    test "unknown trip IDs are ignored" do
      tu = TripUpdate.new(trip_id: "unknown")
      assert {:cont, ^tu, _} = filter(tu, @state)
    end

    test "other values are returned as-is" do
      assert {:cont, :value, _} = filter(:value, @state)
    end
  end
end
