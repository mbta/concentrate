defmodule Concentrate.Filter.IncludeStopIDTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Concentrate.Filter.IncludeStopID
  alias Concentrate.StopTimeUpdate

  defmodule FakeStopTimes do
    @moduledoc "Fake implementation of GTFS.StopTimes"
    def stop_id("trip", 1), do: "stop"
    def stop_id(_, _), do: :unknown
  end

  defp filter(stu), do: IncludeStopID.filter(stu, FakeStopTimes)

  describe "filter/2" do
    test "a stop time update with a stop_id is kept as-is" do
      stu = StopTimeUpdate.new(trip_id: "trip", stop_id: "s", stop_sequence: 1)
      assert {:cont, ^stu} = filter(stu)
    end

    test "a stop update without a trip is kept as-is" do
      stu = StopTimeUpdate.new([])
      assert {:cont, ^stu} = filter(stu)
    end

    test "a missing stop id is updated" do
      stu = StopTimeUpdate.new(trip_id: "trip", stop_sequence: 1)
      assert {:cont, new_stu} = filter(stu)
      assert StopTimeUpdate.stop_id(new_stu) == "stop"
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
