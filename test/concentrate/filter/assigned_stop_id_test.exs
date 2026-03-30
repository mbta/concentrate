defmodule Concentrate.Filter.AssignedStopIDTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Concentrate.Filter.AssignedStopID
  alias Concentrate.StopTimeUpdate

  defmodule FakeStopTimes do
    @moduledoc "Fake implementation of GTFS.StopTimes"
    def stop_id("trip", 1), do: "stop"
    def stop_id(_, _), do: :unknown
  end

  defp filter(stu), do: AssignedStopID.filter(stu, FakeStopTimes)

  describe "filter/2" do
    test "a stop time update with a non-matching assigned_stop_id is kept as-is" do
      stu =
        StopTimeUpdate.new(trip_id: "trip", stop_sequence: 1, assigned_stop_id: "updated_stop")

      assert {:cont, ^stu} = filter(stu)
    end

    test "a stop time update with a matching assigned_trip_id has assigned_stop_id filtered out" do
      stu = StopTimeUpdate.new(trip_id: "trip", stop_sequence: 1, assigned_stop_id: "stop")

      {:cont, new_stu} = filter(stu)
      assert StopTimeUpdate.assigned_stop_id(new_stu) == nil
    end

    test "a stop time update without an assigned_trip_id is returned as-is" do
      stu = StopTimeUpdate.new(trip_id: "trip", stop_sequence: 1, stop_id: "stop")
      assert {:cont, ^stu} = filter(stu)
    end

    test "unknown trip IDs are ignored" do
      stu = StopTimeUpdate.new(trip_id: "unknown")
      assert {:cont, ^stu} = filter(stu)
    end

    test "other values are returned as-is" do
      assert {:cont, :value} = filter(:value)
    end
  end
end
