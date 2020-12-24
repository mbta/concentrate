defmodule Concentrate.GroupFilter.ShuttleTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.GroupFilter.Shuttle
  alias Concentrate.{TripDescriptor, StopTimeUpdate}

  @trip_id "trip"
  @route_id "route"
  @valid_date {1970, 1, 1}
  @valid_date_time 8

  @module Concentrate.Filter.FakeShuttles

  # trip ID: trip
  # route ID: route
  # stops being shuttled: shuttle_1, shuttle_2
  # stop before: before_before_shuttle, before_shuttle
  # stop after: after_shuttle

  # expected behavior:
  # if the vehicle for the trip is not after the shuttle, skip everything after the shuttle starts
  # if the vehicle is after the shuttle, nothing happens

  describe "filter/3" do
    test "unknown stop IDs are ignored" do
      td =
        TripDescriptor.new(
          trip_id: @trip_id,
          route_id: @route_id,
          start_date: @valid_date
        )

      stu =
        StopTimeUpdate.new(
          trip_id: @trip_id,
          stop_id: "unknown",
          departure_time: @valid_date_time
        )

      group = {td, [], [stu]}
      assert filter(group) == group
    end

    test "trip updates without a date or route are left alone" do
      td = TripDescriptor.new(route_id: @route_id)
      assert {^td, [], []} = filter({td, [], []})

      td = TripDescriptor.new(start_date: {1970, 1, 1})
      assert {^td, [], []} = filter({td, [], []})
    end

    test "everything after the shuttle is skipped" do
      group =
        {TripDescriptor.new(
           trip_id: @trip_id,
           route_id: @route_id,
           start_date: {1970, 1, 1}
         ), [],
         [
           StopTimeUpdate.new(
             trip_id: @trip_id,
             stop_id: "before_before_shuttle",
             arrival_time: @valid_date_time,
             departure_time: @valid_date_time
           ),
           StopTimeUpdate.new(
             trip_id: @trip_id,
             stop_id: "before_shuttle",
             arrival_time: @valid_date_time,
             departure_time: @valid_date_time
           ),
           StopTimeUpdate.new(
             trip_id: @trip_id,
             stop_id: "shuttle_1",
             arrival_time: @valid_date_time,
             departure_time: @valid_date_time
           ),
           StopTimeUpdate.new(
             trip_id: @trip_id,
             stop_id: "shuttle_2",
             arrival_time: @valid_date_time,
             departure_time: @valid_date_time
           ),
           StopTimeUpdate.new(
             trip_id: @trip_id,
             stop_id: "after_shuttle",
             arrival_time: @valid_date_time
           )
         ]}

      {_td, [], reduced} = filter(group, @module)

      assert [before_before, before, one, two, after_shuttle] = reduced
      assert StopTimeUpdate.schedule_relationship(before_before) == :SCHEDULED
      assert StopTimeUpdate.arrival_time(before_before)
      assert StopTimeUpdate.schedule_relationship(before) == :SCHEDULED
      assert StopTimeUpdate.schedule_relationship(one) == :SKIPPED
      assert StopTimeUpdate.schedule_relationship(two) == :SKIPPED
      assert StopTimeUpdate.schedule_relationship(after_shuttle) == :SKIPPED
    end

    test "only the first part is skipped if the first stop is shuttled" do
      group =
        {TripDescriptor.new(
           trip_id: @trip_id,
           route_id: @route_id,
           start_date: {1970, 1, 1}
         ), [],
         [
           StopTimeUpdate.new(
             trip_id: @trip_id,
             stop_id: "shuttle_1",
             departure_time: @valid_date_time
           ),
           StopTimeUpdate.new(
             trip_id: @trip_id,
             stop_id: "after_shuttle",
             arrival_time: @valid_date_time,
             departure_time: @valid_date_time
           ),
           StopTimeUpdate.new(
             trip_id: @trip_id,
             stop_id: "after_after_shuttle",
             arrival_time: @valid_date_time
           )
         ]}

      {_td, [], reduced} = filter(group, @module)
      assert [one, after_shuttle, after_after_shuttle] = reduced
      assert StopTimeUpdate.schedule_relationship(one) == :SKIPPED
      assert StopTimeUpdate.schedule_relationship(after_shuttle) == :SCHEDULED
      assert StopTimeUpdate.arrival_time(after_shuttle) == nil
      assert StopTimeUpdate.schedule_relationship(after_after_shuttle) == :SCHEDULED
    end

    test "adjusts arrival time if you can board at the first shuttled stop" do
      group =
        {TripDescriptor.new(
           trip_id: @trip_id,
           route_id: @route_id,
           start_date: {1970, 1, 1}
         ), [],
         [
           StopTimeUpdate.new(
             trip_id: @trip_id,
             stop_id: "shuttle_1",
             departure_time: @valid_date_time
           ),
           StopTimeUpdate.new(
             trip_id: @trip_id,
             stop_id: "shuttle_stop",
             departure_time: @valid_date_time,
             arrival_time: @valid_date_time
           ),
           StopTimeUpdate.new(
             trip_id: @trip_id,
             stop_id: "after_shuttle",
             arrival_time: @valid_date_time,
             departure_time: @valid_date_time
           )
         ]}

      {_td, [], reduced} = filter(group, @module)
      assert [start, stop, after_shuttle] = reduced
      assert StopTimeUpdate.schedule_relationship(start) == :SKIPPED
      assert StopTimeUpdate.schedule_relationship(stop) == :SCHEDULED
      assert StopTimeUpdate.arrival_time(stop) == nil
      assert StopTimeUpdate.schedule_relationship(after_shuttle) == :SCHEDULED
    end

    test "updates are left alone if they're past the shuttle" do
      group =
        {TripDescriptor.new(
           trip_id: @trip_id,
           route_id: @route_id,
           start_date: {1970, 1, 1}
         ), [],
         [
           StopTimeUpdate.new(
             trip_id: @trip_id,
             stop_id: "after_shuttle",
             arrival_time: @valid_date_time
           )
         ]}

      {_td, [], reduced} = filter(group, @module)
      assert [after_shuttle] = reduced
      assert StopTimeUpdate.schedule_relationship(after_shuttle) == :SCHEDULED
    end

    test "stop updates are left alone if they didn't have a time before" do
      group =
        {TripDescriptor.new(
           trip_id: @trip_id,
           route_id: @route_id,
           start_date: {1970, 1, 1}
         ), [],
         [
           StopTimeUpdate.new(
             trip_id: @trip_id,
             stop_id: "after_shuttle"
           )
         ]}

      assert ^group = filter(group, @module)
    end

    test "single direction shuttles don't affect the other direction" do
      direction_0_group =
        {TripDescriptor.new(
           trip_id: @trip_id,
           route_id: "single_direction",
           direction_id: 0,
           start_date: {1970, 1, 1}
         ), [],
         [
           StopTimeUpdate.new(
             trip_id: @trip_id,
             stop_id: "shuttle_1",
             arrival_time: @valid_date_time
           )
         ]}

      {_td, [], [direction_0]} = filter(direction_0_group, @module)
      assert StopTimeUpdate.schedule_relationship(direction_0) == :SKIPPED

      direction_1_group =
        {TripDescriptor.new(
           trip_id: @trip_id <> "_other_way",
           route_id: "single_direction",
           direction_id: 1,
           start_date: {1970, 1, 1}
         ), [],
         [
           StopTimeUpdate.new(
             trip_id: @trip_id <> "_other_way",
             stop_id: "shuttle_1",
             arrival_time: @valid_date_time
           )
         ]}

      {_td, [], [direction_1]} = filter(direction_1_group, @module)
      assert StopTimeUpdate.schedule_relationship(direction_1) == :SCHEDULED
    end

    test "shuttles on trips at the same time aren't affected" do
      group =
        {TripDescriptor.new(
           trip_id: "other_trip",
           route_id: @route_id,
           direction_id: 0,
           start_date: {1970, 1, 1}
         ), [],
         [
           StopTimeUpdate.new(
             trip_id: "other_trip",
             stop_id: "shuttle_1",
             arrival_time: @valid_date_time
           )
         ]}

      assert ^group = filter(group, @module)
    end

    test "shuttles which don't affect exiting leave the arrival time but skip the other stops" do
      group =
        {TripDescriptor.new(
           trip_id: @trip_id,
           route_id: @route_id,
           start_date: {1970, 1, 1}
         ), [],
         [
           StopTimeUpdate.new(
             trip_id: @trip_id,
             stop_id: "before_shuttle",
             departure_time: @valid_date_time
           ),
           StopTimeUpdate.new(
             trip_id: @trip_id,
             stop_id: "shuttle_start",
             arrival_time: @valid_date_time,
             departure_time: @valid_date_time
           ),
           StopTimeUpdate.new(
             trip_id: @trip_id,
             stop_id: "shuttle_1",
             arrival_time: @valid_date_time,
             departure_time: @valid_date_time
           ),
           StopTimeUpdate.new(
             trip_id: @trip_id,
             stop_id: "shuttle_stop",
             arrival_time: @valid_date_time,
             departure_time: @valid_date_time
           ),
           StopTimeUpdate.new(
             trip_id: @trip_id,
             stop_id: "after_shuttle",
             arrival_time: @valid_date_time
           )
         ]}

      {_td, [], reduced} = filter(group, @module)

      assert [before_shuttle, start, one, stop, after_shuttle] = reduced
      assert StopTimeUpdate.schedule_relationship(before_shuttle) == :SCHEDULED
      assert StopTimeUpdate.schedule_relationship(start) == :SCHEDULED
      assert StopTimeUpdate.departure_time(start) == nil
      assert StopTimeUpdate.arrival_time(start)
      assert StopTimeUpdate.schedule_relationship(one) == :SKIPPED
      assert StopTimeUpdate.schedule_relationship(stop) == :SKIPPED
      assert StopTimeUpdate.schedule_relationship(after_shuttle) == :SKIPPED
    end

    test "shuttles which don't affect boarding leave the departure time" do
      group =
        {TripDescriptor.new(
           trip_id: @trip_id,
           route_id: @route_id,
           start_date: {1970, 1, 1}
         ), [],
         [
           StopTimeUpdate.new(
             trip_id: @trip_id,
             stop_id: "shuttle_stop",
             arrival_time: @valid_date_time,
             departure_time: @valid_date_time
           ),
           StopTimeUpdate.new(
             trip_id: @trip_id,
             stop_id: "after_shuttle",
             arrival_time: @valid_date_time,
             departure_time: @valid_date_time
           ),
           StopTimeUpdate.new(
             trip_id: @trip_id,
             stop_id: "after_shuttle_2",
             arrival_time: @valid_date_time
           )
         ]}

      {_td, [], reduced} = filter(group, @module)

      assert [stop, after_shuttle, _] = reduced
      assert StopTimeUpdate.schedule_relationship(stop) == :SCHEDULED
      refute StopTimeUpdate.arrival_time(stop)
      assert StopTimeUpdate.departure_time(stop)
      assert StopTimeUpdate.schedule_relationship(after_shuttle) == :SCHEDULED
      assert StopTimeUpdate.arrival_time(after_shuttle)
    end

    test "does not modify the arrival time if it comes entirely after the shuttle" do
      group =
        {TripDescriptor.new(
           trip_id: @trip_id,
           route_id: @route_id,
           start_date: {1970, 1, 1}
         ), [],
         [
           StopTimeUpdate.new(
             trip_id: @trip_id,
             stop_id: "after_shuttle_1",
             arrival_time: @valid_date_time,
             departure_time: @valid_date_time
           ),
           StopTimeUpdate.new(
             trip_id: @trip_id,
             stop_id: "after_shuttle_2",
             arrival_time: @valid_date_time
           )
         ]}

      {_td, [], reduced} = filter(group, @module)

      assert [stop, _] = reduced
      assert StopTimeUpdate.schedule_relationship(stop) == :SCHEDULED
      assert StopTimeUpdate.arrival_time(stop)
      assert StopTimeUpdate.departure_time(stop)
    end

    test "updates on non-shuttle trips are not modified" do
      group =
        {TripDescriptor.new(trip_id: "other_trip", start_date: @valid_date), [],
         [
           StopTimeUpdate.new(
             trip_id: "other_trip",
             stop_id: "1",
             departure_time: @valid_date_time
           ),
           StopTimeUpdate.new(trip_id: "other_trip", stop_id: "2", arrival_time: @valid_date_time)
         ]}

      assert ^group = filter(group, @module)
    end

    test "other values are returned as-is" do
      assert filter(:value) == :value
    end
  end
end
