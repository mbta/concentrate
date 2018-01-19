defmodule Concentrate.Filter.TimeOutOfRangeTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Filter.TimeOutOfRange
  alias Concentrate.StopTimeUpdate

  @state {5, 10, MapSet.new()}

  describe "filter/2" do
    test "removes StopTimeUpdates if they're in the past or future" do
      stu = StopTimeUpdate.new(arrival_time: 6)
      assert {:cont, ^stu, state} = filter(stu, @state)

      stu = StopTimeUpdate.new(departure_time: 9)
      assert {:cont, ^stu, state} = filter(stu, state)

      stu = StopTimeUpdate.new(arrival_time: 4)
      assert {:skip, state} = filter(stu, state)

      stu = StopTimeUpdate.new(arrival_time: 11)
      assert {:skip, _state} = filter(stu, state)
    end

    test "keeps stop time update if a previous update was in the range" do
      stu = StopTimeUpdate.new(trip_id: "trip", arrival_time: 6)
      assert {:cont, ^stu, state} = filter(stu, @state)

      stu = StopTimeUpdate.new(trip_id: "trip", arrival_time: 11)
      assert {:cont, ^stu, _state} = filter(stu, state)
    end

    test "other values are returned as-is" do
      assert {:cont, :value, _} = filter(:value, @state)
    end
  end
end
