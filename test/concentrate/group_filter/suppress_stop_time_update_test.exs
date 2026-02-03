defmodule Concentrate.GroupFilter.SuppressStopTimeUpdateTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  alias Concentrate.GroupFilter.SuppressStopTimeUpdate
  alias Concentrate.GTFS.Stops
  alias Concentrate.{StopTimeUpdate, TripDescriptor}

  defmodule FakeStopPredictionStatus do
    def suppressed_stops_on_route("Red", 0), do: MapSet.new(["place-hymnl"])
    def suppressed_stops_on_route("Red", 1), do: MapSet.new([])
    def suppressed_stops_on_route(_, _), do: MapSet.new()

    def terminals_suppressed("Red", 0), do: MapSet.new(["70086"])
    def terminals_suppressed("Red", 1), do: MapSet.new(["place-hymnl"])
    def terminals_suppressed(_, _), do: MapSet.new()
  end

  def fake_now do
    DateTime.new(~D[2026-02-03], ~T[12:00:00], "America/New_York")
  end

  def fake_now_during_suppression_range do
    DateTime.new(~D[2026-02-03], ~T[07:00:00], "America/New_York")
  end

  describe "filter/1" do
    setup do
      start_supervised!(Stops)
      Stops._insert_mapping("70152", "place-hymnl")
      Stops._insert_mapping("70086", "place-jfk")
      Stops._insert_mapping("70276", "place-matt")
    end

    test "removes stop_time_updates based on stop suppressions and logs a message" do
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
          assert {^td, [], [^stu2, ^stu3]} =
                   SuppressStopTimeUpdate.filter(
                     {td, [], stus},
                     FakeStopPredictionStatus,
                     &fake_now/0
                   )
        end)

      assert log =~
               "Predictions for stop_id=\"70152\" route_id=Red direction_id=0 have been suppressed based on Screenplay API trigger"

      refute log =~ "stop_id=70086"
      refute log =~ "stop_id=70053"
    end

    test "removes all stop_time_updates for terminal suppression when update_type is 'at_terminal'" do
      td = TripDescriptor.new(route_id: "Red", direction_id: 0, update_type: "at_terminal")

      stu1 = StopTimeUpdate.new(stop_id: "70086")
      stu2 = StopTimeUpdate.new(stop_id: "70152")
      stu3 = StopTimeUpdate.new(stop_id: "70053")

      stus = [
        stu1,
        stu2,
        stu3
      ]

      log =
        capture_log(fn ->
          assert {^td, [], []} =
                   SuppressStopTimeUpdate.filter(
                     {td, [], stus},
                     FakeStopPredictionStatus,
                     &fake_now/0
                   )
        end)

      assert log =~
               "event=terminal_predictions_suppression route_id=Red direction_id=0 have been suppressed based on Screenplay API trigger"
    end

    test "removes all stop_time_updates for terminal suppression when update_type is 'reverse_trip'" do
      td = TripDescriptor.new(route_id: "Red", direction_id: 1, update_type: "reverse_trip")

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
          assert {^td, [], []} =
                   SuppressStopTimeUpdate.filter(
                     {td, [], stus},
                     FakeStopPredictionStatus,
                     &fake_now/0
                   )
        end)

      assert log =~
               "event=terminal_predictions_suppression route_id=Red direction_id=1 have been suppressed based on Screenplay API trigger"
    end

    test "does not remove stop_time_updates for terminal suppression when first stop is not a suppressed terminal" do
      td = TripDescriptor.new(route_id: "Red", direction_id: 0, update_type: "at_terminal")

      # Not a terminal stop
      stu1 = StopTimeUpdate.new(stop_id: "70053")
      stu2 = StopTimeUpdate.new(stop_id: "70086")
      stu3 = StopTimeUpdate.new(stop_id: "70152")

      stus = [
        stu1,
        stu2,
        stu3
      ]

      log =
        capture_log(fn ->
          assert {^td, [], [^stu1, ^stu2]} =
                   SuppressStopTimeUpdate.filter(
                     {td, [], stus},
                     FakeStopPredictionStatus,
                     &fake_now/0
                   )
        end)

      refute log =~ "event=terminal_predictions_suppression"
      assert log =~ "Predictions for stop_id=\"70152\""
    end

    test "requires route_id to filter out stus" do
      td = TripDescriptor.new(route_id: nil, direction_id: 0, update_type: "mid_trip")

      stu1 = StopTimeUpdate.new(stop_id: "0")
      stu2 = StopTimeUpdate.new(stop_id: "123")
      stu3 = StopTimeUpdate.new(stop_id: "4")

      stus = [
        stu1,
        stu2,
        stu3
      ]

      log =
        capture_log(fn ->
          assert {^td, [], [^stu1, ^stu2, ^stu3]} =
                   SuppressStopTimeUpdate.filter(
                     {td, [], stus},
                     FakeStopPredictionStatus,
                     &fake_now/0
                   )
        end)

      refute log =~ "suppressed based on Screenplay API trigger"
    end

    test "requires direction_id to filter out stus" do
      td = TripDescriptor.new(route_id: "Red", direction_id: nil, update_type: "mid_trip")

      stu1 = StopTimeUpdate.new(stop_id: "0")
      stu2 = StopTimeUpdate.new(stop_id: "123")
      stu3 = StopTimeUpdate.new(stop_id: "4")

      stus = [
        stu1,
        stu2,
        stu3
      ]

      log =
        capture_log(fn ->
          assert {^td, [], [^stu1, ^stu2, ^stu3]} =
                   SuppressStopTimeUpdate.filter(
                     {td, [], stus},
                     FakeStopPredictionStatus,
                     &fake_now/0
                   )
        end)

      refute log =~ "suppressed based on Screenplay API trigger"
    end

    test "removes all stop_time_updates for time-based terminal suppression" do
      td = TripDescriptor.new(route_id: "Mattapan", direction_id: 1, update_type: "at_terminal")

      stu1 = StopTimeUpdate.new(stop_id: "70276")
      stu2 = StopTimeUpdate.new(stop_id: "70274")
      stu3 = StopTimeUpdate.new(stop_id: "70272")

      stus = [
        stu1,
        stu2,
        stu3
      ]

      log =
        capture_log(fn ->
          assert {^td, [], []} =
                   SuppressStopTimeUpdate.filter(
                     {td, [], stus},
                     FakeStopPredictionStatus,
                     &fake_now_during_suppression_range/0
                   )
        end)

      assert log =~
               "event=terminal_predictions_suppression_by_time route_id=Mattapan direction_id=1 have been suppressed based on time range"
    end

    test "does not remove stop_time_updates for time-based terminal suppression outside of time range" do
      td = TripDescriptor.new(route_id: "Mattapan", direction_id: 1, update_type: "at_terminal")

      stu1 = StopTimeUpdate.new(stop_id: "70276")
      stu2 = StopTimeUpdate.new(stop_id: "70274")
      stu3 = StopTimeUpdate.new(stop_id: "70272")

      stus = [
        stu1,
        stu2,
        stu3
      ]

      log =
        capture_log(fn ->
          assert {^td, [], [^stu1, ^stu2, ^stu3]} =
                   SuppressStopTimeUpdate.filter(
                     {td, [], stus},
                     FakeStopPredictionStatus,
                     &fake_now/0
                   )
        end)

      refute log =~
               "event=terminal_predictions_suppression_by_time route_id=Mattapan direction_id=1 have been suppressed based on time range"
    end
  end
end
