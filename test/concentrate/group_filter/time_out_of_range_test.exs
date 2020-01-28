defmodule Concentrate.GroupFilter.TimeOutOfRangeTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.GroupFilter.TimeOutOfRange
  alias Concentrate.StopTimeUpdate

  defp now do
    1000
  end

  describe "filter/1" do
    test "removes StopTimeUpdates if they're in the past or future" do
      stu = StopTimeUpdate.new(arrival_time: 1000)
      assert {_, [], [^stu]} = filter({nil, [], [stu]}, &now/0)

      stu = StopTimeUpdate.new(departure_time: 10_000)
      assert {_, [], [^stu]} = filter({nil, [], [stu]}, &now/0)

      stu = StopTimeUpdate.new(arrival_time: 4)
      assert {_, [], []} = filter({nil, [], [stu]}, &now/0)

      stu = StopTimeUpdate.new(arrival_time: 400)
      assert {_, [], [^stu]} = filter({nil, [], [stu]}, &now/0)

      stu = StopTimeUpdate.new(arrival_time: 12_000)
      assert {_, [], []} = filter({nil, [], [stu]}, &now/0)
    end

    test "keeps stop time update if a previous update was in the range" do
      stus = [
        StopTimeUpdate.new(arrival_time: 1000),
        StopTimeUpdate.new(arrival_time: 120_000)
      ]

      group = {nil, [], stus}
      assert filter(group, &now/0) == group
    end

    test "other values are returned as-is" do
      assert filter(:value, &now/0) == :value
    end
  end
end
