defmodule Concentrate.GroupFilter.SplitThroughRoutedTripsTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.GroupFilter.SplitThroughRoutedTrips
  alias Concentrate.Encoder.TripGroup
  alias Concentrate.{StopTimeUpdate, TripDescriptor, VehiclePosition}

  @fake_split_trips Concentrate.GTFS.FakeSplitTrips

  defmodule FakeStopTimes do
    def stops_for_trip("trip_1"),
      do: [
        {1, "stop1"},
        {2, "stop2"},
        {3, "stop3"}
      ]

    def stops_for_trip("trip_2"),
      do: [
        {3, "stop3"},
        {4, "stop4"},
        {5, "stop5"}
      ]

    def stops_for_trip("trip_3"),
      do: [
        {5, "stop5"},
        {6, "stop6"},
        {7, "stop7"}
      ]

    def stops_for_trip(_), do: :unknown
  end

  defmodule FakeTrips do
    def route_id("trip_1"), do: "39"
    def route_id("trip_2"), do: "66"
    def route_id("trip_3"), do: "57"
    def route_id("other"), do: "1"
    def route_id(_), do: nil

    def direction_id("trip_1"), do: "1"
    def direction_id("trip_2"), do: "0"
    def direction_id("trip_3"), do: "0"
    def direction_id("other"), do: "1"
    def direction_id(_), do: nil
  end

  describe "filter/2" do
    test "copies relevant updates for each component trip" do
      td =
        TripDescriptor.new(
          trip_id: "trip",
          route_id: "39",
          start_date: {1970, 1, 2}
        )

      stus = [
        StopTimeUpdate.new(
          trip_id: "trip",
          arrival_time: 86_406,
          stop_sequence: 1
        ),
        StopTimeUpdate.new(
          trip_id: "trip",
          arrival_time: 86_466,
          stop_sequence: 2
        ),
        StopTimeUpdate.new(
          trip_id: "trip",
          arrival_time: 86_526,
          stop_sequence: 3
        ),
        StopTimeUpdate.new(
          trip_id: "trip",
          arrival_time: 86_586,
          stop_sequence: 4
        ),
        StopTimeUpdate.new(
          trip_id: "trip",
          arrival_time: 86_646,
          stop_sequence: 5
        ),
        StopTimeUpdate.new(
          trip_id: "trip",
          arrival_time: 86_706,
          stop_sequence: 6
        ),
        StopTimeUpdate.new(
          trip_id: "trip",
          arrival_time: 86_766,
          stop_sequence: 7
        )
      ]

      vp = VehiclePosition.new(trip_id: "trip", latitude: 1, longitude: 2, stop_sequence: 3)

      group = %TripGroup{td: td, vps: [vp], stus: stus}

      assert [
               %TripGroup{
                 td: %TripDescriptor{trip_id: "trip_1"},
                 vps: [%VehiclePosition{trip_id: "trip_1"}],
                 stus: [
                   %StopTimeUpdate{trip_id: "trip_1", stop_sequence: 1},
                   %StopTimeUpdate{trip_id: "trip_1", stop_sequence: 2},
                   %StopTimeUpdate{trip_id: "trip_1", stop_sequence: 3}
                 ]
               },
               %TripGroup{
                 td: %TripDescriptor{trip_id: "trip_2"},
                 vps: [%VehiclePosition{trip_id: "trip_2"}],
                 stus: [
                   %StopTimeUpdate{trip_id: "trip_2", stop_sequence: 3},
                   %StopTimeUpdate{trip_id: "trip_2", stop_sequence: 4},
                   %StopTimeUpdate{trip_id: "trip_2", stop_sequence: 5}
                 ]
               },
               %TripGroup{
                 td: %TripDescriptor{trip_id: "trip_3"},
                 vps: [],
                 stus: [
                   %StopTimeUpdate{trip_id: "trip_3", stop_sequence: 5},
                   %StopTimeUpdate{trip_id: "trip_3", stop_sequence: 6},
                   %StopTimeUpdate{trip_id: "trip_3", stop_sequence: 7}
                 ]
               }
             ] =
               filter(group, @fake_split_trips, FakeStopTimes, FakeTrips)
    end

    test "ignores trips that are not through-routed" do
      td =
        TripDescriptor.new(
          trip_id: "other",
          start_date: {1970, 1, 2}
        )

      stu =
        StopTimeUpdate.new(
          trip_id: "other",
          arrival_time: 50
        )

      group = %TripGroup{td: td, stus: [stu]}
      assert filter(group, @fake_split_trips, FakeStopTimes, FakeTrips) == group
    end
  end
end
