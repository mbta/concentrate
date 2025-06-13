defmodule Concentrate.GroupFilter.CancelledTripTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.GroupFilter.CancelledTrip
  alias Concentrate.{StopTimeUpdate, TripDescriptor}

  @module Concentrate.Filter.FakeCancelledTrips
  @fake_routes_module Concentrate.GTFS.FakeRoutes

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
      {new_td, [], [new_stu]} = filter(group, @module, @fake_routes_module)
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
      {new_td, [], [new_stu]} = filter(group, @module, @fake_routes_module)
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
      {_td, [], [stu]} = filter(group, @module, @fake_routes_module)
      assert StopTimeUpdate.schedule_relationship(stu) == :SKIPPED
    end

    test "cancels the group if all stop updates have already been given a skipped status" do
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
          schedule_relationship: :SKIPPED
        )

      group = {td, [], [stu, stu]}
      {td_actual, [], [stu_actual1, stu_actual2]} = filter(group, @module, @fake_routes_module)
      assert TripDescriptor.schedule_relationship(td_actual) == :CANCELED
      assert StopTimeUpdate.schedule_relationship(stu_actual1) == :SKIPPED
      assert StopTimeUpdate.schedule_relationship(stu_actual2) == :SKIPPED
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
      {td_actual, [], [stu_actual1, stu_actual2]} = filter(group, @module, @fake_routes_module)
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
      {td_actual, [], [stu_actual1, stu_actual2]} = filter(group, @module, @fake_routes_module)
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
      assert filter(group, @module, @fake_routes_module) == group
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
      assert filter(group, @module, @fake_routes_module) == group
    end

    test "other values are returned as-is" do
      assert filter(:value) == :value
    end
  end
end
