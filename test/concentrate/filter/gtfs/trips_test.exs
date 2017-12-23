defmodule Concentrate.Filter.GTFS.TripsTest do
  @moduledoc false
  use ExUnit.Case
  import Concentrate.Filter.GTFS.Trips

  @body """
  trip_id,route_id,direction_id
  trip,route,5
  """

  setup do
    {:ok, _pid} = start_link([])
    event = [{"trips.txt", @body}]
    # relies on being able to update the table from a different process
    handle_events([event], :ignored, :ignored)
    :ok
  end

  describe "route_id/1" do
    test "returns the route_id for the given trip" do
      assert route_id("trip") == "route"
      assert route_id("unknown") == nil
    end
  end

  describe "direction_id/1" do
    test "returns the direction_id for the given trip" do
      assert direction_id("trip") == 5
      assert direction_id("unknown") == nil
    end
  end
end
