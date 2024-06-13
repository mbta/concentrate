defmodule Concentrate.GroupFilter.SuppressStopTimeUpdateTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  import Concentrate.GroupFilter.SuppressStopTimeUpdate
  alias Concentrate.StopTimeUpdate
  alias Concentrate.TripDescriptor

  defmodule FakeStopPredictionStatus do
    def flagged_stops_on_route("Red", 0), do: MapSet.new([123])
    def flagged_stops_on_route(_, _), do: nil
  end

  describe "filter/1" do
    test "removes stop_time_updates of the corresponding trip_id + direction_id + stop_id combos if they are currently flagged and logs a messge" do
      td = TripDescriptor.new(route_id: "Red", direction_id: 0, update_type: "mid_trip")

      stu1 = StopTimeUpdate.new(stop_id: 0)
      stu2 = StopTimeUpdate.new(stop_id: 123)
      stu3 = StopTimeUpdate.new(stop_id: 4)

      stus = [
        stu1,
        stu2,
        stu3
      ]

      log =
        capture_log(fn ->
          assert {^td, [], [^stu1, ^stu3]} = filter({td, [], stus}, FakeStopPredictionStatus)
        end)

      assert log =~
               "Predictions for stop_id=123 route_id=Red direction_id=0 have been suppressed based on RTS feed trigger"
    end

    test "requires route_id to filter out stus" do
      td = TripDescriptor.new(route_id: nil, direction_id: 0, update_type: "mid_trip")

      stu1 = StopTimeUpdate.new(stop_id: 0)
      stu2 = StopTimeUpdate.new(stop_id: 123)
      stu3 = StopTimeUpdate.new(stop_id: 4)

      stus = [
        stu1,
        stu2,
        stu3
      ]

      log =
        capture_log(fn ->
          assert {^td, [], [^stu1, ^stu2, ^stu3]} =
                   filter({td, [], stus}, FakeStopPredictionStatus)
        end)

      refute log =~ "suppressed based on RTS feed trigger"
    end

    test "requires direction_id to filter out stus" do
      td = TripDescriptor.new(route_id: "Red", direction_id: nil, update_type: "mid_trip")

      stu1 = StopTimeUpdate.new(stop_id: 0)
      stu2 = StopTimeUpdate.new(stop_id: 123)
      stu3 = StopTimeUpdate.new(stop_id: 4)

      stus = [
        stu1,
        stu2,
        stu3
      ]

      log =
        capture_log(fn ->
          assert {^td, [], [^stu1, ^stu2, ^stu3]} =
                   filter({td, [], stus}, FakeStopPredictionStatus)
        end)

      refute log =~ "suppressed based on RTS feed trigger"
    end
  end
end
