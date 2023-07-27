defmodule Concentrate.Filter.UnscheduledScheduledStopTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Concentrate.StopTimeUpdate
  import Concentrate.Filter.UnscheduledScheduledStop

  describe "filter/1" do
    test "a stop time update with an arrival and/or departure is kept" do
      stu = StopTimeUpdate.new(arrival_time: %{time: 1}, departure_time: nil)
      assert {:cont, ^stu} = filter(stu)

      stu = StopTimeUpdate.new(arrival_time: nil, departure_time: %{time: 1})
      assert {:cont, ^stu} = filter(stu)
    end

    test "a skipped stop time update is kept" do
      stu =
        StopTimeUpdate.new(
          arrival_time: nil,
          departure_time: nil,
          schedule_relationship: :SKIPPED
        )

      assert {:cont, ^stu} = filter(stu)
    end

    test "a stop time update with a boarding status is kept" do
      stu = StopTimeUpdate.new(arrival_time: nil, departure_time: nil, status: "On time")
      assert {:cont, ^stu} = filter(stu)
    end

    test "scheduled stop time updates with no arrival/departure are skipped" do
      stu =
        StopTimeUpdate.new(
          arrival_time: nil,
          departure_time: nil,
          schedule_relationship: :SCHEDULED
        )

      assert :skip = filter(stu)
    end
  end
end
