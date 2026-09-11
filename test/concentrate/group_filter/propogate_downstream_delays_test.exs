defmodule Concentrate.GroupFilter.PropogateDownstreamDelaysTest do
  use ExUnit.Case, async: true

  alias Concentrate.Encoder.TripGroup
  alias Concentrate.GroupFilter.PropogateDownstreamDelays
  alias Concentrate.GTFS.{FakeRoutes, StopTimes}
  alias Concentrate.{StopTimeUpdate, TripDescriptor}

  defmodule FakeStopTimes do
    def stops_for_trip_with_arrival_departure("trip", _date),
      do: [
        {10, "stop1", 85_000, 85_001},
        {20, "stop2", 86_000, 86_001},
        {30, "stop3", 87_100, 87_101}
      ]

    def stops_for_trip_with_arrival_departure(_, _), do: :unknown
  end

  describe "filter/2" do
    test "trip descriptor not scheduled" do
      td =
        TripDescriptor.new(
          trip_id: "trip",
          start_date: {2026, 1, 1},
          schedule_relationship: :CANCELED
        )

      stu = StopTimeUpdate.new(trip_id: "trip", status: :CANCELED)

      group = %TripGroup{td: td, stus: [stu]}

      assert group == PropogateDownstreamDelays.filter(group)
    end

    test "doesn't propogate delays if the route is not commuter rail" do
      td =
        TripDescriptor.new(
          trip_id: "trip",
          route_id: "66",
          start_date: {2026, 1, 1},
          schedule_relationship: :SCHEDULED
        )

      stu = StopTimeUpdate.new(trip_id: "trip", status: "Delayed")

      group = %TripGroup{td: td, stus: [stu]}

      now_fn = fn -> 88_000 end

      assert group == PropogateDownstreamDelays.filter(group, StopTimes, FakeRoutes, now_fn)
    end

    test "doesn't propogate delays if the first stop time status isn't in delaying status list" do
      td =
        TripDescriptor.new(
          trip_id: "trip",
          route_id: "CR_1",
          start_date: {2026, 1, 1},
          schedule_relationship: :SCHEDULED
        )

      stu_1 = StopTimeUpdate.new(trip_id: "trip", status: "On time", stop_sequence: 10)

      group = %TripGroup{td: td, stus: [stu_1]}

      now_fn = fn -> 88_000 end

      assert group == PropogateDownstreamDelays.filter(group, FakeStopTimes, FakeRoutes, now_fn)
    end

    test "doesn't propagate delays for stops before the first delayed stop" do
      td =
        TripDescriptor.new(
          trip_id: "trip",
          route_id: "CR_1",
          start_date: {2026, 1, 1},
          schedule_relationship: :SCHEDULED
        )

      stu_2 =
        StopTimeUpdate.new(
          trip_id: "trip",
          status: "Delayed",
          stop_id: "stop2",
          stop_sequence: 20
        )

      group = %TripGroup{td: td, stus: [stu_2]}

      now_fn = fn -> 88_000 end

      assert %TripGroup{
               td: td,
               stus: [
                 stu_2,
                 StopTimeUpdate.new(
                   trip_id: "trip",
                   status: "Delayed",
                   stop_id: "stop3",
                   stop_sequence: 30
                 )
               ]
             } == PropogateDownstreamDelays.filter(group, FakeStopTimes, FakeRoutes, now_fn)
    end

    test "adds stop time updates only when they don't already exist" do
      td =
        TripDescriptor.new(
          trip_id: "trip",
          route_id: "CR_1",
          start_date: {2026, 1, 1},
          schedule_relationship: :SCHEDULED
        )

      stu_1 =
        StopTimeUpdate.new(
          trip_id: "trip",
          status: "Delayed",
          stop_id: "stop1",
          stop_sequence: 10
        )

      stu_2 =
        StopTimeUpdate.new(
          trip_id: "trip",
          arrival_time: 86_000,
          departure_time: 86_001,
          stop_id: "stop2",
          stop_sequence: 20
        )

      group = %TripGroup{td: td, stus: [stu_1, stu_2]}

      now_fn = fn -> 88_000 end

      assert %TripGroup{
               td: td,
               stus: [
                 stu_1,
                 stu_2,
                 StopTimeUpdate.new(
                   trip_id: "trip",
                   status: "Delayed",
                   stop_id: "stop3",
                   stop_sequence: 30
                 )
               ]
             } == PropogateDownstreamDelays.filter(group, FakeStopTimes, FakeRoutes, now_fn)
    end

    test "adds stop time updates only for scheduled departures in the past" do
      td =
        TripDescriptor.new(
          trip_id: "trip",
          route_id: "CR_1",
          start_date: {2026, 1, 1},
          schedule_relationship: :SCHEDULED
        )

      stu_1 =
        StopTimeUpdate.new(
          trip_id: "trip",
          status: "Delayed",
          stop_id: "stop1",
          stop_sequence: 10
        )

      group = %TripGroup{td: td, stus: [stu_1]}

      now_fn = fn -> 86_500 end

      assert %TripGroup{
               td: td,
               stus: [
                 stu_1,
                 StopTimeUpdate.new(
                   trip_id: "trip",
                   status: "Delayed",
                   stop_id: "stop2",
                   stop_sequence: 20
                 )
               ]
             } == PropogateDownstreamDelays.filter(group, FakeStopTimes, FakeRoutes, now_fn)
    end
  end
end
