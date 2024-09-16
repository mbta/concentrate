defmodule Concentrate.GTFS.TripsTest do
  @moduledoc false
  use ExUnit.Case
  import Concentrate.GTFS.Trips

  @body """
  trip_id,route_id,direction_id
  trip,route,5
  """

  @routes_body """
  route_id,route_type
  route,3
  """

  defp supervised(_) do
    start_supervised(Concentrate.GTFS.Trips)
    event = [{"trips.txt", @body}, {"routes.txt", @routes_body}]
    # relies on being able to update the table from a different process
    handle_events([event], :ignored, :ignored)
    :ok
  end

  describe "route_id/1" do
    setup :supervised

    test "returns the route_id for the given trip" do
      assert route_id("trip") == "route"
      assert route_id("unknown") == nil
    end
  end

  describe "direction_id/1" do
    setup :supervised

    test "returns the direction_id for the given trip" do
      assert direction_id("trip") == 5
      assert direction_id("unknown") == nil
    end
  end

  describe "route_type/1" do
    setup :supervised

    test "returns the direction_id for the given trip" do
      assert route_type("trip") == 3
      assert route_type("unknown") == nil
    end
  end

  describe "missing ETS table" do
    test "route_id/1 returns nil" do
      assert route_id("trip") == nil
    end

    test "direction_id/1 returns nil" do
      assert direction_id("trip") == nil
    end
  end
end
