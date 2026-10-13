defmodule Concentrate.GroupFilter.SplitThroughRoutedTripsTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.GroupFilter.SplitThroughRoutedTrips
  alias Concentrate.Encoder.TripGroup
  alias Concentrate.{StopTimeUpdate, TripDescriptor, VehiclePosition}

  @fake_split_trips Concentrate.GTFS.FakeSplitTrips

  describe "filter/2" do
    test "copies the group for each component trip" do
      td =
        TripDescriptor.new(
          trip_id: "trip",
          route_id: "route",
          start_date: {1970, 1, 2}
        )

      stu =
        StopTimeUpdate.new(
          trip_id: "trip",
          arrival_time: 86_406
        )

      vp = VehiclePosition.new(trip_id: "trip", latitude: 1, longitude: 2)

      group = %TripGroup{td: td, vps: [vp], stus: [stu]}

      assert [
               %TripGroup{
                 td: %TripDescriptor{trip_id: "trip_1"},
                 vps: [%VehiclePosition{trip_id: "trip_1"}],
                 stus: [%StopTimeUpdate{trip_id: "trip_1"}]
               },
               %TripGroup{
                 td: %TripDescriptor{trip_id: "trip_2"},
                 vps: [%VehiclePosition{trip_id: "trip_2"}],
                 stus: [%StopTimeUpdate{trip_id: "trip_2"}]
               },
               %TripGroup{
                 td: %TripDescriptor{trip_id: "trip_3"},
                 vps: [%VehiclePosition{trip_id: "trip_3"}],
                 stus: [%StopTimeUpdate{trip_id: "trip_3"}]
               }
             ] =
               filter(group, @fake_split_trips)
    end

    test "ignores trips that are not through-routed" do
      td =
        TripDescriptor.new(
          trip_id: "other-trip",
          start_date: {1970, 1, 2}
        )

      stu =
        StopTimeUpdate.new(
          trip_id: "other_trip",
          arrival_time: 50
        )

      group = %TripGroup{td: td, stus: [stu]}
      assert filter(group, @fake_split_trips) == group
    end
  end
end
