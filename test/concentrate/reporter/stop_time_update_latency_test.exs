defmodule Concentrate.Reporter.STopTimeUpdateLatencyTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Reporter.StopTimeUpdateLatency
  alias Concentrate.StopTimeUpdate

  describe "log/2" do
    test "logs undefined if there aren't any stop time updates with timestamps" do
      state = init()

      assert {[earliest_stop_time_update: :undefined, latest_stop_time_update: :undefined], _} =
               log([], state)

      assert {[earliest_stop_time_update: :undefined, latest_stop_time_update: :undefined], _} =
               log([{nil, [], [StopTimeUpdate.new([])]}], state)
    end

    test "logs the difference with utc_now from the most-up-to-date vehicle" do
      state = init()
      stu = StopTimeUpdate.new([])
      now = utc_now()

      group = {
        Concentrate.TripDescriptor.new([]),
        [],
        [
          StopTimeUpdate.update_arrival_time(stu, now - 5),
          StopTimeUpdate.update_departure_time(stu, now - 3),
          StopTimeUpdate.update(stu, arrival_time: now + 1, departure_time: now + 2)
        ]
      }

      assert {[earliest_stop_time_update: -5, latest_stop_time_update: 1], _} =
               log([group], state)
    end
  end

  def utc_now do
    DateTime.to_unix(DateTime.utc_now())
  end
end
