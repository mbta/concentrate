defmodule Concentrate.GroupFilter.ClosedStopTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.GroupFilter.ClosedStop
  alias Concentrate.{TripDescriptor, StopTimeUpdate, VehiclePosition}

  @trip_update TripDescriptor.new(trip_id: "trip", direction_id: 1, route_id: "route")
  @valid_date_time 8
  @invalid_date_time 4

  @module Concentrate.Filter.FakeClosedStops

  describe "filter/2" do
    test "unknown stop IDs are ignored" do
      stu = StopTimeUpdate.new(stop_id: "unknown", departure_time: @valid_date_time)
      group = {@trip_update, [], [stu]}
      assert ^group = filter(group, @module)
    end

    test "skips the stop time if the stop is closed during the timeframe" do
      stu =
        StopTimeUpdate.new(
          trip_id: "trip",
          stop_id: "stop",
          arrival_time: @valid_date_time,
          departure_time: @valid_date_time
        )

      group = {@trip_update, [], [stu]}
      assert {_, _, [new_stu]} = filter(group, @module)
      assert StopTimeUpdate.schedule_relationship(new_stu) == :SKIPPED
      assert StopTimeUpdate.arrival_time(new_stu) == nil
      assert StopTimeUpdate.departure_time(new_stu) == nil
    end

    test "skips the stop time if the stop is closed for the whole route" do
      td =
        TripDescriptor.new(
          trip_id: "other_trip",
          route_id: "other_route"
        )

      stu =
        StopTimeUpdate.new(
          trip_id: "other_trip",
          stop_id: "route_stop",
          arrival_time: @valid_date_time,
          departure_time: @valid_date_time
        )

      group = {td, [], [stu]}
      assert {_, _, [new_stu]} = filter(group, @module)
      assert StopTimeUpdate.schedule_relationship(new_stu) == :SKIPPED
      assert StopTimeUpdate.arrival_time(new_stu) == nil
      assert StopTimeUpdate.departure_time(new_stu) == nil
    end

    test "does not skip the stop time if the stop is closed at a different time" do
      stu =
        StopTimeUpdate.new(
          trip_id: "trip",
          stop_id: "stop",
          departure_time: @invalid_date_time
        )

      group = {@trip_update, [], [stu]}
      assert ^group = filter(group, @module)
    end

    test "does not skip the stop time if the stop is closed on a different route" do
      stu =
        StopTimeUpdate.new(
          trip_id: "trip",
          stop_id: "route_stop",
          departure_time: @valid_date_time
        )

      group = {@trip_update, [], [stu]}
      assert ^group = filter(group, @module)
    end

    test "does not modify the update if there are no times" do
      stu =
        StopTimeUpdate.new(
          trip_id: "trip",
          stop_id: "route_stop"
        )

      group = {@trip_update, [], [stu]}
      assert ^group = filter(group)
    end

    test "does not modify the group if there's no TripDescriptor" do
      group = {nil, [VehiclePosition.new(id: "vehicle", latitude: 0, longitude: 0)], []}
      assert ^group = filter(group)
    end
  end
end
