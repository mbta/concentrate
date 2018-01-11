defmodule Concentrate.Filter.CancelledTripTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Filter.CancelledTrip
  alias Concentrate.{TripUpdate, StopTimeUpdate}

  @state {Concentrate.Filter.FakeCancelledTrips, %{}}

  describe "filter/2" do
    test "TripUpdate is cancelled if the start date matches" do
      tu =
        TripUpdate.new(
          trip_id: "trip",
          start_date: {1970, 1, 1}
        )

      assert {:cont, new_tu, _} = filter(tu, @state)
      assert TripUpdate.schedule_relationship(new_tu) == :CANCELED
    end

    test "TripUpdate is not cancelled if the start date does not match" do
      tu =
        TripUpdate.new(
          trip_id: "trip",
          start_date: {1970, 1, 2}
        )

      assert {:cont, ^tu, _} = filter(tu, @state)
    end

    test "TripUpdate is not cancelled if the trip ID does not match" do
      tu =
        TripUpdate.new(
          trip_id: "other trip",
          start_date: {1970, 1, 1}
        )

      assert {:cont, ^tu, _} = filter(tu, @state)
    end

    test "TripUpdate is cancelled if the route is cancelled" do
      tu =
        TripUpdate.new(
          trip_id: "other_trip",
          route_id: "route",
          start_date: {1970, 1, 2}
        )

      assert {:cont, new_tu, _} = filter(tu, @state)
      assert TripUpdate.schedule_relationship(new_tu) == :CANCELED
    end

    test "TripUpdate is not cancelled if the route is not cancelled" do
      tu =
        TripUpdate.new(
          trip_id: "other_trip",
          route_id: "route",
          start_date: {1970, 1, 1}
        )

      assert {:cont, ^tu, {_, map}} = filter(tu, @state)
      assert map == %{}
    end

    test "TripUpdate is not cancelled if it doesn't have a start date" do
      tu =
        TripUpdate.new(
          trip_id: "trip",
          route_id: "route"
        )

      assert {:cont, ^tu, _state} = filter(tu, @state)
    end

    test "StopTimeUpdate is skipped if the trip ID and time match" do
      stu =
        StopTimeUpdate.new(
          trip_id: "trip",
          arrival_time: 8
        )

      assert {:cont, new_stu, _} = filter(stu, @state)
      assert new_stu == StopTimeUpdate.skip(stu)
    end

    test "StopTimeUpdate is not skipped if the time does not match" do
      stu =
        StopTimeUpdate.new(
          trip_id: "trip",
          arrival_time: 50
        )

      assert {:cont, ^stu, _} = filter(stu, @state)
    end

    test "StopTimeUpdate is skipped if the route was cancelled" do
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

      {:cont, _, state} = filter(tu, @state)
      assert {:cont, new_stu, _} = filter(stu, state)
      assert new_stu == StopTimeUpdate.skip(stu)
    end

    test "StopTimeUpdate is not skipped if the route was cancelled at a different time" do
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

      {:cont, _, state} = filter(tu, @state)
      assert {:cont, ^stu, _} = filter(stu, state)
    end

    test "other values are returned as-is" do
      assert {:cont, :value, _} = filter(:value, @state)
    end
  end
end
