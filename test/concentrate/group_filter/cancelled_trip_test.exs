defmodule Concentrate.GroupFilter.CancelledTripTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.GroupFilter.CancelledTrip
  alias Concentrate.{TripUpdate, StopTimeUpdate}

  @module Concentrate.Filter.FakeCancelledTrips

  describe "filter/2" do
    test "cancels the group if the trip is cancelled by an alert" do
      tu =
        TripUpdate.new(
          trip_id: "trip",
          start_date: {1970, 1, 1}
        )

      stu =
        StopTimeUpdate.new(
          trip_id: "trip",
          arrival_time: 8
        )

      group = {tu, [], [stu]}
      {new_tu, [], [new_stu]} = filter(group, @module)
      assert TripUpdate.schedule_relationship(new_tu) == :CANCELED
      assert StopTimeUpdate.schedule_relationship(new_stu) == :SKIPPED
    end

    test "cancels the group if the route is cancelled by an alert" do
      tu =
        TripUpdate.new(
          trip_id: "other_trip",
          route_id: "route",
          start_date: {1970, 1, 2}
        )

      stu =
        StopTimeUpdate.new(
          trip_id: "other_trip",
          arrival_time: 86_406
        )

      group = {tu, [], [stu]}
      {new_tu, [], [new_stu]} = filter(group, @module)
      assert TripUpdate.schedule_relationship(new_tu) == :CANCELED
      assert StopTimeUpdate.schedule_relationship(new_stu) == :SKIPPED
    end

    test "cancels the group if the trip is cancelled upstream" do
      tu =
        TripUpdate.new(
          trip_id: "trip",
          schedule_relationship: :CANCELED,
          start_date: {1970, 1, 2}
        )

      stu =
        StopTimeUpdate.new(
          trip_id: "trip",
          status: :CANCELED
        )

      group = {tu, [], [stu]}
      {_tu, [], [stu]} = filter(group, @module)
      assert StopTimeUpdate.schedule_relationship(stu) == :SKIPPED
    end

    test "leaves non-cancelled trips alone" do
      tu =
        TripUpdate.new(
          trip_id: "trip",
          start_date: {1970, 1, 2}
        )

      stu =
        StopTimeUpdate.new(
          trip_id: "trip",
          arrival_time: 50
        )

      group = {tu, [], [stu]}
      assert filter(group, @module) == group
    end

    test "does not cancel the group if the route was cancelled at a different time" do
      tu =
        TripUpdate.new(
          trip_id: "other_trip",
          route_id: "route",
          start_date: {1970, 1, 2}
        )

      stu =
        StopTimeUpdate.new(
          trip_id: "other_trip",
          arrival_time: 87_000
        )

      group = {tu, [], [stu]}
      assert filter(group, @module) == group
    end

    test "other values are returned as-is" do
      assert filter(:value) == :value
    end
  end
end
