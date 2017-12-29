defmodule Concentrate.Filter.ClosedStopTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Filter.ClosedStop
  alias Concentrate.StopTimeUpdate

  @valid_date_time DateTime.from_unix!(8)
  @invalid_date_time DateTime.from_unix!(4)

  @state {Concentrate.Filter.FakeClosedStops, Concentrate.Filter.FakeTrips}

  describe "filter/2" do
    test "unknown stop IDs are ignored" do
      stu = StopTimeUpdate.new(stop_id: "unknown", departure_time: @valid_date_time)
      assert {:cont, ^stu, _} = filter(stu, @state)
    end

    test "skips the stop time if the stop is closed during the timeframe" do
      stu =
        StopTimeUpdate.new(
          trip_id: "trip",
          stop_id: "stop",
          arrival_time: @valid_date_time
        )

      assert {:cont, new_stu, _} = filter(stu, @state)
      assert StopTimeUpdate.schedule_relationship(new_stu) == :SKIPPED
    end

    test "does not skip the stop time if the stop is closed at a different time" do
      stu =
        StopTimeUpdate.new(
          trip_id: "trip",
          stop_id: "stop",
          departure_time: @invalid_date_time
        )

      assert {:cont, ^stu, _} = filter(stu, @state)
    end

    test "does not skip the stop time if the stop is closed on a different route" do
      stu =
        StopTimeUpdate.new(
          trip_id: "trip",
          stop_id: "route_stop",
          departure_time: @valid_date_time
        )

      assert {:cont, ^stu, _} = filter(stu, @state)
    end

    test "other values are returned as-is" do
      assert {:cont, :value, _} = filter(:value, @state)
    end
  end
end
