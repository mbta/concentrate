defmodule Concentrate.Filter.RemoveUnneededTimesTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Filter.RemoveUnneededTimes
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

  @state {__MODULE__.FakePickupDropOff, MapSet.new()}
  @arrival_time 5
  @departure_time 500
  @stu StopTimeUpdate.new(
         trip_id: "trip",
         arrival_time: @arrival_time,
         departure_time: @departure_time
       )

  describe "filter/2" do
    test "a stop time update with a different stop_sequence isn't modified" do
      stu = @stu
      assert {:cont, ^stu, _} = filter(stu, @state)
    end

    test "the arrival_time is removed from the first stop sequence" do
      stu = StopTimeUpdate.update(@stu, stop_sequence: 1)
      expected = StopTimeUpdate.update(stu, arrival_time: nil)
      assert {:cont, ^expected, _} = filter(stu, @state)
    end

    test "the departure_time is removed from the last stop sequence" do
      stu = StopTimeUpdate.update(@stu, stop_sequence: 5)
      expected = StopTimeUpdate.update(stu, departure_time: nil)
      assert {:cont, ^expected, _} = filter(stu, @state)
    end

    test "if the departure time is missing from the first stop, use the arrival time" do
      stu = StopTimeUpdate.update(@stu, stop_sequence: 1, departure_time: nil)
      expected = StopTimeUpdate.update(stu, arrival_time: nil, departure_time: @arrival_time)
      assert {:cont, ^expected, _} = filter(stu, @state)
    end

    test "if the arrival time is missing from the last stop, use the departure time" do
      stu = StopTimeUpdate.update(@stu, stop_sequence: 5, arrival_time: nil)
      expected = StopTimeUpdate.update(stu, arrival_time: @departure_time, departure_time: nil)
      assert {:cont, ^expected, _} = filter(stu, @state)
    end

    test "other stop sequence values are left alone" do
      stu = StopTimeUpdate.update(@stu, stop_sequence: 3)
      assert {:cont, ^stu, _} = filter(stu, @state)
    end

    test "arrival time is copied if only the departure time is available" do
      stu = StopTimeUpdate.update(@stu, arrival_time: nil)
      assert {:cont, stu, _} = filter(stu, @state)
      assert StopTimeUpdate.arrival_time(stu) == @departure_time
    end

    test "departure time is copied if only the arrival time is available" do
      stu = StopTimeUpdate.update(@stu, departure_time: nil)
      assert {:cont, stu, _} = filter(stu, @state)
      assert StopTimeUpdate.departure_time(stu) == @arrival_time
    end

    test "if we can neither pickup or drop off, skip the update" do
      stu = StopTimeUpdate.update(@stu, stop_sequence: 6)
      expected = StopTimeUpdate.skip(stu)
      assert {:cont, ^expected, _} = filter(stu, @state)
    end

    test "non-scheduled TripUpdates aren't modified" do
      tu = TripUpdate.new(trip_id: "added", schedule_relationship: :ADDED)
      stu = StopTimeUpdate.update(@stu, trip_id: "added", departure_time: nil)
      assert {:cont, ^tu, state} = filter(tu, @state)
      assert {:cont, ^stu, _state} = filter(stu, state)
    end

    test "other values are returned as-is" do
      assert {:cont, :value, _} = filter(:value, @state)
    end
  end
end
