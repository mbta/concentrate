defmodule Concentrate.Filter.ShuttleTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Filter.Shuttle
  alias Concentrate.Filter.Shuttle
  alias Concentrate.{TripUpdate, StopTimeUpdate}

  @trip_id "trip"
  @route_id "route"
  @valid_date_time 8

  @state %Shuttle{module: Concentrate.Filter.FakeShuttles}

  # trip ID: trip
  # route ID: route
  # stops being shuttled: shuttle_1, shuttle_2
  # stop before: before_shuttle
  # stop after: after_shuttle

  # expected behavior:
  # if the vehicle for the trip is not after the shuttle, skip everything after the shuttle starts
  # if the vehicle is after the shuttle, nothing happens

  describe "filter/3" do
    test "unknown stop IDs are ignored" do
      stu =
        StopTimeUpdate.new(
          trip_id: @trip_id,
          stop_id: "unknown",
          departure_time: @valid_date_time
        )

      assert {:cont, ^stu, _} = filter(stu, nil, @state)
    end

    test "trip updates without a date or route are left alone" do
      tu = TripUpdate.new(route_id: @route_id)
      assert {:cont, ^tu, _} = filter(tu, nil, @state)

      tu = TripUpdate.new(start_date: {1970, 1, 1})
      assert {:cont, ^tu, _} = filter(tu, nil, @state)
    end

    test "everything after the shuttle is skipped" do
      updates = [
        TripUpdate.new(
          trip_id: @trip_id,
          route_id: @route_id,
          start_date: {1970, 1, 1}
        ),
        StopTimeUpdate.new(
          trip_id: @trip_id,
          stop_id: "before_before_shuttle",
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
      ]

      reduced = run(updates)

      assert [_tu, before_before, before, one, two, after_shuttle] = reduced
      assert StopTimeUpdate.schedule_relationship(before_before) == :SCHEDULED
      assert StopTimeUpdate.schedule_relationship(before) == :SCHEDULED
      assert StopTimeUpdate.schedule_relationship(one) == :SKIPPED
      assert StopTimeUpdate.schedule_relationship(two) == :SKIPPED
      assert StopTimeUpdate.schedule_relationship(after_shuttle) == :SKIPPED
    end

    test "the last stop before the shuttle has no departure time" do
      updates = [
        TripUpdate.new(
          trip_id: @trip_id,
          route_id: @route_id,
          start_date: {1970, 1, 1}
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
        )
      ]

      reduced = run(updates)
      assert [_tu, before, _one] = reduced
      assert StopTimeUpdate.departure_time(before) == nil
    end

    test "everything is skipped if the first stop is shuttled" do
      updates = [
        TripUpdate.new(
          trip_id: @trip_id,
          route_id: @route_id,
          start_date: {1970, 1, 1}
        ),
        StopTimeUpdate.new(
          trip_id: @trip_id,
          stop_id: "shuttle_1",
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
      ]

      reduced = run(updates)
      assert [_tu, one, two, after_shuttle] = reduced
      assert StopTimeUpdate.schedule_relationship(one) == :SKIPPED
      assert StopTimeUpdate.schedule_relationship(two) == :SKIPPED
      assert StopTimeUpdate.schedule_relationship(after_shuttle) == :SKIPPED
    end

    test "updates are left alone if they're past the shuttle" do
      updates = [
        TripUpdate.new(
          trip_id: @trip_id,
          route_id: @route_id,
          start_date: {1970, 1, 1}
        ),
        StopTimeUpdate.new(
          trip_id: @trip_id,
          stop_id: "after_shuttle",
          arrival_time: @valid_date_time
        )
      ]

      reduced = run(updates)
      assert [_tu, after_shuttle] = reduced
      assert StopTimeUpdate.schedule_relationship(after_shuttle) == :SCHEDULED
    end

    test "stop updates are left alone if they didn't have a time before" do
      updates = [
        TripUpdate.new(
          trip_id: @trip_id,
          route_id: @route_id,
          start_date: {1970, 1, 1}
        ),
        StopTimeUpdate.new(
          trip_id: @trip_id,
          stop_id: "after_shuttle"
        )
      ]

      reduced = run(updates)
      assert ^updates = reduced
    end

    test "single direction shuttles don't affect the other direction" do
      updates = [
        TripUpdate.new(
          trip_id: @trip_id,
          route_id: "single_direction",
          direction_id: 0,
          start_date: {1970, 1, 1}
        ),
        TripUpdate.new(
          trip_id: @trip_id <> "_other_way",
          route_id: "single_direction",
          direction_id: 1,
          start_date: {1970, 1, 1}
        ),
        StopTimeUpdate.new(
          trip_id: @trip_id,
          stop_id: "shuttle_1",
          arrival_time: @valid_date_time
        ),
        StopTimeUpdate.new(
          trip_id: @trip_id <> "_other_way",
          stop_id: "shuttle_1",
          arrival_time: @valid_date_time
        )
      ]

      reduced = run(updates)
      assert [_tu_0, _tu_1, direction_0, direction_1] = reduced
      assert StopTimeUpdate.schedule_relationship(direction_0) == :SKIPPED
      assert StopTimeUpdate.schedule_relationship(direction_1) == :SCHEDULED
    end

    test "shuttles on trips at the same time aren't affected" do
      updates = [
        TripUpdate.new(
          trip_id: "other_trip",
          route_id: @route_id,
          direction_id: 0,
          start_date: {1970, 1, 1}
        ),
        StopTimeUpdate.new(
          trip_id: "other_trip",
          stop_id: "shuttle_1",
          arrival_time: @valid_date_time
        )
      ]

      assert ^updates = run(updates)
    end

    test "updates on non-shuttles trips are not modified" do
      updates = [
        StopTimeUpdate.new(trip_id: "other_trip", stop_id: "1", departure_time: @valid_date_time),
        StopTimeUpdate.new(trip_id: "other_trip", stop_id: "2", arrival_time: @valid_date_time)
      ]

      reduced = run(updates)
      assert updates == reduced
    end

    test "other values are returned as-is" do
      assert {:cont, :value, _} = filter(:value, nil, @state)
    end
  end

  defp run(updates) do
    next_updates = Enum.drop(updates, 1) ++ [nil]

    {reduced, _} =
      Enum.flat_map_reduce(Enum.zip(updates, next_updates), @state, fn {item, next_item}, state ->
        case filter(item, next_item, state) do
          {:cont, item, state} -> {[item], state}
        end
      end)

    reduced
  end
end
