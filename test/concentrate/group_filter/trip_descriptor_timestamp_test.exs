defmodule Concentrate.GroupFilter.TripDescriptorTimestampTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.GroupFilter.TripDescriptorTimestamp
  alias Concentrate.Encoder.TripGroup
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

      expected = %TripGroup{
        td: %{td | timestamp: VehiclePosition.last_updated(vp)},
        vps: [vp]
      }

      assert filter(%TripGroup{td: td, vps: [vp]}) == expected
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

      expected = %TripGroup{
        td: %{td | timestamp: VehiclePosition.last_updated(vp2)},
        vps: [vp1, vp2]
      }

      assert filter(%TripGroup{td: td, vps: [vp1, vp2]}) == expected
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

      expected = %TripGroup{td: td, vps: [vp]}

      assert filter(%TripGroup{td: td, vps: [vp]}) == expected
    end
  end
end
