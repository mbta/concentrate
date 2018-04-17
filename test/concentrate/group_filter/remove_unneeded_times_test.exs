defmodule Concentrate.GroupFilter.RemoveUnneededTimesTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.GroupFilter.RemoveUnneededTimes
  alias Concentrate.{TripUpdate, StopTimeUpdate}

  defmodule FakePickupDropOff do
    @moduledoc "Fake implementation of Filter.GTFS.PickupDropOff"
    def pickup?("trip", 5), do: false
    def pickup?("trip", 6), do: false
    def pickup?(_, _), do: true

    def drop_off?("trip", 1), do: false
    def drop_off?("trip", 6), do: false
    def drop_off?(_, _), do: true
  end

  @module __MODULE__.FakePickupDropOff
  @arrival_time 5
  @departure_time 500
  @tu TripUpdate.new(trip_id: "trip")
  @stu StopTimeUpdate.new(
         trip_id: "trip",
         arrival_time: @arrival_time,
         departure_time: @departure_time
       )

  describe "filter/1" do
    test "a stop time update with a different stop_sequence isn't modified" do
      group = {@tu, [], [@stu]}
      assert filter(group, @module) == group
    end

    test "the arrival_time is removed if there's no drop off" do
      stu = StopTimeUpdate.update(@stu, stop_sequence: 1)
      group = {@tu, [], [stu]}
      expected = StopTimeUpdate.update(stu, arrival_time: nil)
      assert {_, [], [^expected]} = filter(group, @module)
    end

    test "the departure_time is removed if there's no pickup" do
      stu = StopTimeUpdate.update(@stu, stop_sequence: 5)
      group = {@tu, [], [stu]}
      expected = StopTimeUpdate.update(stu, departure_time: nil)
      assert {_, [], [^expected]} = filter(group, @module)
    end

    test "a departure_time is not removed if there are stops added afterward" do
      # stop sequence 6 is skipped
      stus =
        for seq <- [5, 7] do
          StopTimeUpdate.update(@stu, stop_sequence: seq)
        end

      group = {@tu, [], stus}
      # no chanages
      assert filter(group, @module) == group
    end

    test "if the departure time is missing from the first stop, use the arrival time" do
      stu = StopTimeUpdate.update(@stu, stop_sequence: 1, departure_time: nil)
      group = {@tu, [], [stu]}
      expected = StopTimeUpdate.update(stu, arrival_time: nil, departure_time: @arrival_time)
      assert {_, [], [^expected]} = filter(group, @module)
    end

    test "if the arrival time is missing from the last stop, use the departure time" do
      stu = StopTimeUpdate.update(@stu, stop_sequence: 5, arrival_time: nil)
      group = {@tu, [], [stu]}
      expected = StopTimeUpdate.update(stu, arrival_time: @departure_time, departure_time: nil)
      assert {_, [], [^expected]} = filter(group, @module)
    end

    test "other stop sequence values are left alone" do
      stu = StopTimeUpdate.update(@stu, stop_sequence: 3)
      group = {@tu, [], [stu]}
      assert filter(group, @module) == group
    end

    test "arrival time is copied if only the departure time is available" do
      stu = StopTimeUpdate.update(@stu, arrival_time: nil)
      group = {@tu, [], [stu]}
      {_, [], [stu]} = filter(group, @module)
      assert StopTimeUpdate.arrival_time(stu) == @departure_time
    end

    test "departure time is copied if only the arrival time is available" do
      stu = StopTimeUpdate.update(@stu, departure_time: nil)
      group = {@tu, [], [stu]}
      {_, [], [stu]} = filter(group, @module)
      assert StopTimeUpdate.departure_time(stu) == @arrival_time
    end

    test "if we can neither pickup or drop off, skip the update" do
      stu = StopTimeUpdate.update(@stu, stop_sequence: 6)
      group = {@tu, [], [stu]}
      expected = StopTimeUpdate.skip(stu)
      assert {_, [], [^expected]} = filter(group, @module)
    end

    test "non-scheduled TripUpdates aren't modified" do
      tu = TripUpdate.new(trip_id: "added", schedule_relationship: :ADDED)
      stu = StopTimeUpdate.update(@stu, trip_id: "added", departure_time: nil)
      group = {tu, [], [stu]}
      assert filter(group, @module) == group
    end

    test "other values are returned as-is" do
      assert filter(:value, @module) == :value
    end
  end
end
