defmodule Concentrate.GroupFilter.CancelledTripTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.GroupFilter.CancelledTrip
  alias Concentrate.{StopTimeUpdate, TripDescriptor}

  @module Concentrate.Filter.FakeCancelledTrips
  @fake_routes_module Concentrate.GTFS.FakeRoutes
  @fake_stop_times_module Concentrate.GTFS.FakeStopTimes

  defmodule FakeStopTimesForBlockWaiver do
    def stops_for_trip("trip"), do: [{10, "stop1"}, {20, "stop2"}, {30, "stop3"}]
    def stops_for_trip(_), do: :unknown

    def arrival_departure("trip", 10, {1970, 1, 2}), do: {85_000, 85_001}
    def arrival_departure("trip", 20, {1970, 1, 2}), do: {87_000, 87_001}
    def arrival_departure("trip", 30, {1970, 1, 2}), do: {87_100, 87_101}
  end

  describe "filter/2" do
    test "cancels the group if the trip is cancelled by an alert" do
      td =
        TripDescriptor.new(
          trip_id: "trip",
          start_date: {1970, 1, 1}
        )

      stu =
        StopTimeUpdate.new(
          trip_id: "trip",
          arrival_time: 8
        )

      group = {td, [], [stu]}

      {new_td, [], [new_stu]} =
        filter(group, @module, @fake_routes_module, @fake_stop_times_module)

      assert TripDescriptor.schedule_relationship(new_td) == :CANCELED
      assert StopTimeUpdate.schedule_relationship(new_stu) == :SKIPPED
    end

    test "cancels the group if the route is cancelled by an alert" do
      td =
        TripDescriptor.new(
          trip_id: "other_trip",
          route_id: "route",
          start_date: {1970, 1, 2}
        )

      stu =
        StopTimeUpdate.new(
          trip_id: "other_trip",
          arrival_time: 86_406
        )

      group = {td, [], [stu]}

      {new_td, [], [new_stu]} =
        filter(group, @module, @fake_routes_module, @fake_stop_times_module)

      assert TripDescriptor.schedule_relationship(new_td) == :CANCELED
      assert StopTimeUpdate.schedule_relationship(new_stu) == :SKIPPED
    end

    test "cancels the group if the trip is cancelled upstream" do
      td =
        TripDescriptor.new(
          trip_id: "trip",
          schedule_relationship: :CANCELED,
          start_date: {1970, 1, 2}
        )

      stu =
        StopTimeUpdate.new(
          trip_id: "trip",
          status: :CANCELED
        )

      group = {td, [], [stu]}
      {_td, [], [stu]} = filter(group, @module, @fake_routes_module, @fake_stop_times_module)
      assert StopTimeUpdate.schedule_relationship(stu) == :SKIPPED
    end

    test "cancels the group if all future stop updates have already been given a skipped status" do
      td =
        TripDescriptor.new(
          route_id: "1",
          trip_id: "trip",
          start_date: {1970, 1, 2}
        )

      stu1 =
        StopTimeUpdate.new(
          trip_id: "trip",
          status: :SCHEDULED,
          arrival_time: 87_000,
          schedule_relationship: :SKIPPED,
          stop_id: "stop2",
          stop_sequence: 20
        )

      stu2 =
        StopTimeUpdate.new(
          trip_id: "trip",
          status: :SCHEDULED,
          arrival_time: 87_100,
          schedule_relationship: :SKIPPED,
          stop_id: "stop3",
          stop_sequence: 30
        )

      now_fn = fn -> 86_000 end

      group = {td, [], [stu1, stu2]}

      {td_actual, [], [stu_actual1, stu_actual2]} =
        filter(
          group,
          @module,
          @fake_routes_module,
          Concentrate.GroupFilter.CancelledTripTest.FakeStopTimesForBlockWaiver,
          now_fn
        )

      assert TripDescriptor.schedule_relationship(td_actual) == :CANCELED
      assert StopTimeUpdate.schedule_relationship(stu_actual1) == :SKIPPED
      assert StopTimeUpdate.schedule_relationship(stu_actual2) == :SKIPPED
    end

    test "cancels the group if all stop updates have a skipped status and stops for trip are unknown" do
      td =
        TripDescriptor.new(
          route_id: "1",
          trip_id: "other_trip",
          start_date: {1970, 1, 2}
        )

      stu1 =
        StopTimeUpdate.new(
          trip_id: "other_trip",
          status: :SCHEDULED,
          arrival_time: 87_000,
          schedule_relationship: :SKIPPED,
          stop_id: "stop2",
          stop_sequence: 20
        )

      stu2 =
        StopTimeUpdate.new(
          trip_id: "other_trip",
          status: :SCHEDULED,
          arrival_time: 87_100,
          schedule_relationship: :SKIPPED,
          stop_id: "stop3",
          stop_sequence: 30
        )

      now_fn = fn -> 86_000 end

      group = {td, [], [stu1, stu2]}

      {td_actual, [], [stu_actual1, stu_actual2]} =
        filter(
          group,
          @module,
          @fake_routes_module,
          Concentrate.GroupFilter.CancelledTripTest.FakeStopTimesForBlockWaiver,
          now_fn
        )

      assert TripDescriptor.schedule_relationship(td_actual) == :CANCELED
      assert StopTimeUpdate.schedule_relationship(stu_actual1) == :SKIPPED
      assert StopTimeUpdate.schedule_relationship(stu_actual2) == :SKIPPED
    end

    test "doesn't cancel the group if not all scheduled stop updates have already been given a skipped status" do
      td =
        TripDescriptor.new(
          route_id: "1",
          trip_id: "trip",
          start_date: {1970, 1, 2}
        )

      stu =
        StopTimeUpdate.new(
          trip_id: "trip",
          status: :SCHEDULED,
          arrival_time: 87_000,
          schedule_relationship: :SKIPPED,
          stop_id: "stop2",
          stop_sequence: 20
        )

      now_fn = fn -> 86_000 end

      group = {td, [], [stu, stu]}

      {td_actual, [], [stu_actual1, stu_actual2]} =
        filter(
          group,
          @module,
          @fake_routes_module,
          Concentrate.GroupFilter.CancelledTripTest.FakeStopTimesForBlockWaiver,
          now_fn
        )

      assert TripDescriptor.schedule_relationship(td_actual) == :SCHEDULED
      assert StopTimeUpdate.schedule_relationship(stu_actual1) == :SKIPPED
      assert StopTimeUpdate.schedule_relationship(stu_actual2) == :SKIPPED
    end

    test "does not cancel the group if there are no stop time updates" do
      td =
        TripDescriptor.new(
          route_id: "1",
          trip_id: "trip",
          start_date: {1970, 1, 2}
        )

      group = {td, [], []}

      {td_actual, [], []} =
        filter(group, @module, @fake_routes_module, @fake_stop_times_module)

      assert TripDescriptor.schedule_relationship(td_actual) == :SCHEDULED
    end

    test "creates SKIPPED STUs if there are no STUs for a CANCELED trip" do
      td =
        TripDescriptor.new(
          route_id: "1",
          trip_id: "trip",
          start_date: {1970, 1, 2},
          schedule_relationship: :CANCELED
        )

      group = {td, [], []}

      {td_actual, [], stus} =
        filter(group, @module, @fake_routes_module, @fake_stop_times_module)

      assert TripDescriptor.schedule_relationship(td_actual) == :CANCELED

      fake_stops = @fake_stop_times_module.stops_for_trip("trip")

      Enum.each(
        fake_stops,
        fn {expected_sequence, expected_stop} ->
          assert Enum.any?(stus, fn %StopTimeUpdate{
                                      stop_sequence: sequence,
                                      stop_id: stop_id,
                                      schedule_relationship: schedule_relationship
                                    } ->
                   sequence == expected_sequence && stop_id == expected_stop &&
                     schedule_relationship == :SKIPPED
                 end)
        end
      )
    end

    test "does not create SKIPPED STUs for a cancelled trip for which we don't have stop times" do
      td =
        TripDescriptor.new(
          route_id: "1",
          trip_id: "unknown",
          start_date: {1970, 1, 2},
          schedule_relationship: :CANCELED
        )

      group = {td, [], []}

      assert {td_actual, [], []} =
               filter(group, @module, @fake_routes_module, @fake_stop_times_module)

      assert TripDescriptor.schedule_relationship(td_actual) == :CANCELED
    end

    test "does not cancel the group if all stop updates have already been given a skipped status but route_type is not 3" do
      td =
        TripDescriptor.new(
          route_id: "Red",
          trip_id: "red_trip",
          start_date: {1970, 1, 2}
        )

      stu =
        StopTimeUpdate.new(
          trip_id: "red_trip",
          status: :SCHEDULED,
          arrival_time: 87_000,
          schedule_relationship: :SKIPPED
        )

      group = {td, [], [stu, stu]}

      {td_actual, [], [stu_actual1, stu_actual2]} =
        filter(group, @module, @fake_routes_module, @fake_stop_times_module)

      assert TripDescriptor.schedule_relationship(td_actual) == :SCHEDULED
      assert StopTimeUpdate.schedule_relationship(stu_actual1) == :SKIPPED
      assert StopTimeUpdate.schedule_relationship(stu_actual2) == :SKIPPED
    end

    test "does not cancel the group if only some stop updates have already been given a skipped schedule relationship" do
      td =
        TripDescriptor.new(
          route_id: "86",
          trip_id: "trip",
          start_date: {1970, 1, 2}
        )

      stu1 =
        StopTimeUpdate.new(
          trip_id: "trip",
          arrival_time: 87_000,
          schedule_relationship: :SKIPPED
        )

      stu2 =
        StopTimeUpdate.new(
          trip_id: "trip",
          arrival_time: 87_000,
          schedule_relationship: :SCHEDULED
        )

      group = {td, [], [stu1, stu2]}

      {td_actual, [], [stu_actual1, stu_actual2]} =
        filter(group, @module, @fake_routes_module, @fake_stop_times_module)

      assert TripDescriptor.schedule_relationship(td_actual) == :SCHEDULED
      assert StopTimeUpdate.schedule_relationship(stu_actual1) == :SKIPPED
      assert StopTimeUpdate.schedule_relationship(stu_actual2) == :SCHEDULED
    end

    test "leaves non-cancelled trips alone" do
      td =
        TripDescriptor.new(
          trip_id: "trip",
          start_date: {1970, 1, 2}
        )

      stu =
        StopTimeUpdate.new(
          trip_id: "trip",
          arrival_time: 50
        )

      group = {td, [], [stu]}
      assert filter(group, @module, @fake_routes_module, @fake_stop_times_module) == group
    end

    test "does not cancel the group if the route was cancelled at a different time" do
      td =
        TripDescriptor.new(
          trip_id: "other_trip",
          route_id: "route",
          start_date: {1970, 1, 2}
        )

      stu =
        StopTimeUpdate.new(
          trip_id: "other_trip",
          arrival_time: 87_000
        )

      group = {td, [], [stu]}
      assert filter(group, @module, @fake_routes_module, @fake_stop_times_module) == group
    end

    test "other values are returned as-is" do
      assert filter(:value) == :value
    end
  end
end
