defmodule Concentrate.GroupFilter.ScreenplaySuppressStopTimeUpdateTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  alias Concentrate.GroupFilter.ScreenplaySuppressStopTimeUpdate
  alias Concentrate.GTFS.Stops
  alias Concentrate.{StopTimeUpdate, TripDescriptor}

  defmodule FakeStopPredictionStatus do
    def flagged_stops_on_route("Red", 0, _), do: MapSet.new(["place-hymnl", "70086"])
    def flagged_stops_on_route(_, _, _), do: []
  end

  describe "filter/1" do
    setup do
      start_supervised!(Stops)
      Stops._insert_mapping("70152", "place-hymnl")
      Stops._insert_mapping("70086", "place-jfk")
    end

    test "removes stop_time_updates of the corresponding trip_id + direction_id + stop_id combos if they are currently flagged and logs a message" do
      td = TripDescriptor.new(route_id: "Red", direction_id: 0, update_type: "mid_trip")

      stu1 = StopTimeUpdate.new(stop_id: "70152")
      stu2 = StopTimeUpdate.new(stop_id: "70086")
      stu3 = StopTimeUpdate.new(stop_id: "70053")

      stus = [
        stu1,
        stu2,
        stu3
      ]

      log =
        capture_log(fn ->
          assert {^td, [], [^stu3]} =
                   ScreenplaySuppressStopTimeUpdate.filter(
                     {td, [], stus},
                     FakeStopPredictionStatus
                   )
        end)

      assert log =~
               "Predictions for stop_id=70152 route_id=Red direction_id=0 have been suppressed based on Screenplay API trigger"

      assert log =~
               "Predictions for stop_id=70086 route_id=Red direction_id=0 have been suppressed based on Screenplay API trigger"
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
                   ScreenplaySuppressStopTimeUpdate.filter(
                     {td, [], stus},
                     FakeStopPredictionStatus
                   )
        end)

      refute log =~ "suppressed based on Screenplay API trigger"
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
                   ScreenplaySuppressStopTimeUpdate.filter(
                     {td, [], stus},
                     FakeStopPredictionStatus
                   )
        end)

      refute log =~ "suppressed based on Screenplay API trigger"
    end
  end
end
