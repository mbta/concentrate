defmodule Concentrate.GroupFilter.TripDescriptorTimestampTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.GroupFilter.TripDescriptorTimestamp
  alias Concentrate.{TripDescriptor, VehiclePosition}

  describe "filter/1" do
    test "populates timestamp in TripDescriptor with corresponding timestamp in VehiclePosition" do
      vp =
        VehiclePosition.new(
          trip_id: "trip",
          latitude: 1,
          longitude: 1,
          last_updated: 1_514_558_974
        )

      td = TripDescriptor.new([])

      assert {%{td | timestamp: VehiclePosition.last_updated(vp)}, [vp], []} ==
               filter({td, [vp], []})
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

      td = TripDescriptor.new([])

      assert {%{td | timestamp: VehiclePosition.last_updated(vp2)}, [vp1, vp2], []} ==
               filter({td, [vp1, vp2], []})
    end

    test "uses timestamp on TripDescriptor if one exists" do
      vp =
        VehiclePosition.new(
          trip_id: "trip",
          latitude: 1,
          longitude: 1,
          last_updated: 1_514_558_974
        )

      td = TripDescriptor.new(timestamp: 1_514_558_900)

      assert {td, [vp], []} ==
               filter({td, [vp], []})
    end

    test "other values are returned as-is" do
      assert filter(:value) == :value
    end
  end
end
