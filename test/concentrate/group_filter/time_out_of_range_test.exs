defmodule Concentrate.GroupFilter.TimeOutOfRangeTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.GroupFilter.TimeOutOfRange
  alias Concentrate.Encoder.TripGroup
  alias Concentrate.StopTimeUpdate

  defp now do
    1000
  end

  describe "filter/1" do
    test "removes StopTimeUpdates if they're in the future but not if they're in the past" do
      stu = StopTimeUpdate.new(arrival_time: 1000)
      assert %TripGroup{stus: [^stu]} = filter(%TripGroup{stus: [stu]}, &now/0)

      stu = StopTimeUpdate.new(departure_time: 10_000)
      assert %TripGroup{stus: [^stu]} = filter(%TripGroup{stus: [stu]}, &now/0)

      stu = StopTimeUpdate.new(arrival_time: 4)
      assert %TripGroup{stus: [^stu]} = filter(%TripGroup{stus: [stu]}, &now/0)

      stu = StopTimeUpdate.new(arrival_time: 400)
      assert %TripGroup{stus: [^stu]} = filter(%TripGroup{stus: [stu]}, &now/0)

      stu = StopTimeUpdate.new(arrival_time: 12_000)
      assert %TripGroup{stus: []} = filter(%TripGroup{stus: [stu]}, &now/0)
    end

    test "keeps stop time update if a previous update was in the range" do
      stus = [
        StopTimeUpdate.new(arrival_time: 1000),
        StopTimeUpdate.new(arrival_time: 120_000)
      ]

      group = %TripGroup{stus: stus}
      assert filter(group, &now/0) == group
    end
  end
end
