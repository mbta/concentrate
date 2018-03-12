defmodule Concentrate.Filter.ClosedStopTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Filter.ClosedStop
  alias Concentrate.StopTimeUpdate

  @valid_date_time 8
  @invalid_date_time 4

  @modules {Concentrate.Filter.FakeClosedStops, Concentrate.Filter.FakeTrips}

  describe "filter/2" do
    test "unknown stop IDs are ignored" do
      stu = StopTimeUpdate.new(stop_id: "unknown", departure_time: @valid_date_time)
      assert {:cont, ^stu} = filter(stu, @modules)
    end

    test "skips the stop time if the stop is closed during the timeframe" do
      stu =
        StopTimeUpdate.new(
          trip_id: "trip",
          stop_id: "stop",
          arrival_time: @valid_date_time,
          departure_time: @valid_date_time
        )

      assert {:cont, new_stu} = filter(stu, @modules)
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

      assert {:cont, ^stu} = filter(stu, @modules)
    end

    test "does not skip the stop time if the stop is closed on a different route" do
      stu =
        StopTimeUpdate.new(
          trip_id: "trip",
          stop_id: "route_stop",
          departure_time: @valid_date_time
        )

      assert {:cont, ^stu} = filter(stu, @modules)
    end

    test "does not modify the update if there are no times" do
      stu =
        StopTimeUpdate.new(
          trip_id: "trip",
          stop_id: "route_stop"
        )

      assert {:cont, ^stu} = filter(stu, @modules)
    end

    test "other values are returned as-is" do
      assert {:cont, :value} = filter(:value)
    end
  end
end
