defmodule Concentrate.GroupFilter.TripUpdateTimestampTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.GroupFilter.TripUpdateTimestamp
  alias Concentrate.{TripUpdate, VehiclePosition}

  describe "filter/1" do
    test "populates timestamp in TripUpdate with corresponding timestamp in VehiclePosition" do
      vp =
        VehiclePosition.new(
          trip_id: "trip",
          latitude: 1,
          longitude: 1,
          last_updated: 1_514_558_974
        )

      tu = TripUpdate.new([])

      assert {%{tu | timestamp: VehiclePosition.last_updated(vp)}, [vp], []} ==
               filter({tu, [vp], []})
    end

    test "use VehiclePostition with max timestamp if more than one is present" do
      vp1 =
        VehiclePosition.new(
          trip_id: "trip",
          latitude: 1,
          longitude: 1,
          last_updated: 1_514_558_974
        )

      vp2 =
        VehiclePosition.new(
          trip_id: "trip",
          latitude: 1,
          longitude: 1,
          last_updated: 1_514_558_975
        )

      tu = TripUpdate.new([])

      assert {%{tu | timestamp: VehiclePosition.last_updated(vp2)}, [vp1, vp2], []} ==
               filter({tu, [vp1, vp2], []})
    end

    test "uses timestamp on TripUpdate if one exists" do
      vp =
        VehiclePosition.new(
          trip_id: "trip",
          latitude: 1,
          longitude: 1,
          last_updated: 1_514_558_974
        )

      tu = TripUpdate.new(timestamp: 1_514_558_900)

      assert {tu, [vp], []} ==
               filter({tu, [vp], []})
    end

    test "other values are returned as-is" do
      assert filter(:value) == :value
    end
  end
end
