defmodule Concentrate.Alert.InformedEntityTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Kernel, except: [match?: 2], warn: false
  import Concentrate.Alert.InformedEntity

  describe "match?/2" do
    test "matches values from the informed entity" do
      ie =
        new(
          trip_id: "trip",
          route_type: 2,
          route_id: "route",
          direction_id: 1,
          stop_id: "stop"
        )

      assert match?(ie, trip_id: "trip")
      assert match?(ie, trip_id: "trip", route_id: "route")
      assert match?(ie, trip_id: nil, route_id: "route")
      refute match?(ie, trip_id: "other")
      refute match?(ie, route_id: "route", direction_id: 0)
    end

    test "nil values in the informed entity match values from the match as long as something matches" do
      ie = new(trip_id: "trip")
      assert match?(ie, trip_id: "trip", route_id: "route")
      # no overlap
      refute match?(ie, route_id: "route")
    end
  end
end
