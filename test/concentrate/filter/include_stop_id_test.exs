defmodule Concentrate.Filter.IncludeStopIDTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Filter.IncludeStopID
  alias Concentrate.StopTimeUpdate

  @module Concentrate.GTFS.FakeStopIDs

  describe "filter/2" do
    test "a stop time update with a stop_id is kept as-is" do
      stu = StopTimeUpdate.new(trip_id: "trip", stop_id: "s", stop_sequence: 1)
      assert {:cont, ^stu} = filter(stu, @module)
    end

    test "a stop update without a trip is kept as-is" do
      stu = StopTimeUpdate.new([])
      assert {:cont, ^stu} = filter(stu, @module)
    end

    test "a missing stop id is updated" do
      stu = StopTimeUpdate.new(trip_id: "trip", stop_sequence: 1)
      assert {:cont, new_stu} = filter(stu, @module)
      assert StopTimeUpdate.stop_id(new_stu) == "stop"
    end

    test "unknown trip IDs are ignored" do
      stu = StopTimeUpdate.new(trip_id: "unknown")
      assert {:cont, ^stu} = filter(stu, @module)
    end

    test "other values are returned as-is" do
      assert {:cont, :value} = filter(:value)
    end
  end
end
