defmodule Concentrate.Filter.IncludeRouteDirectionTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Filter.IncludeRouteDirection
  alias Concentrate.TripDescriptor

  @module Concentrate.GTFS.FakeTrips

  describe "filter/2" do
    test "a trip update with a route/direction is kept as-is" do
      td = TripDescriptor.new(trip_id: "trip", route_id: "r", direction_id: 0)
      assert {:cont, ^td} = filter(td, @module)
    end

    test "a trip update without a trip is kept as-is" do
      td = TripDescriptor.new([])
      assert {:cont, ^td} = filter(td, @module)
    end

    test "a missing route/direction_id is updated" do
      td = TripDescriptor.new(trip_id: "trip")
      assert {:cont, new_td} = filter(td, @module)
      assert TripDescriptor.route_id(new_td) == "route"
      assert TripDescriptor.direction_id(new_td) == 1
    end

    test "unknown trip IDs are ignored" do
      td = TripDescriptor.new(trip_id: "unknown")
      assert {:cont, ^td} = filter(td, @module)
    end

    test "other values are returned as-is" do
      assert {:cont, :value} = filter(:value)
    end
  end
end
