defmodule Concentrate.GTFS.SplitTripsTest do
  @moduledoc false
  use ExUnit.Case
  import Concentrate.GTFS.SplitTrips

  @body """
  trip_id,route_id
  trip_1,39
  trip_2,38
  other,1
  """

  defp supervised(_) do
    start_supervised(Concentrate.GTFS.SplitTrips)
    event = [{"trips.txt", @body}]
    # relies on being able to update the table from a different process
    handle_events([event], :ignored, :ignored)
    :ok
  end

  describe "trip_ids/1" do
    setup :supervised

    test "returns the trip_ids for the given trip" do
      assert trip_ids("trip") == ["trip_1", "trip_2"]
      assert trip_ids("other") == nil
      assert trip_ids("unknown") == nil
    end
  end

  describe "missing ETS table" do
    test "trip_ids/1 returns nil" do
      assert trip_ids("trip") == nil
    end
  end
end
