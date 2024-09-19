defmodule Concentrate.GTFS.RoutesTest do
  @moduledoc false
  use ExUnit.Case
  import Concentrate.GTFS.Routes

  @body """
  route_id,route_type
  route_1,0
  route_2,1
  route_3,2
  """

  defp supervised(_) do
    start_supervised(Concentrate.GTFS.Routes)
    event = [{"routes.txt", @body}]
    # relies on being able to update the table from a different process
    handle_events([event], :ignored, :ignored)
    :ok
  end

  describe "route_type/1" do
    setup :supervised

    test "returns the route_type for the given route_id" do
      assert route_type("route_1") == 0
      assert route_type("route_2") == 1
      assert route_type("route_3") == 2
      assert route_type("unknown") == nil
    end
  end

  describe "missing ETS table" do
    test "route_type/1 returns nil" do
      assert route_type("route_1") == nil
    end
  end
end
