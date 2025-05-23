defmodule Concentrate.Filter.Suppress.Screenplay.StopPredictionStatusTest do
  @moduledoc false
  use ExUnit.Case
  import Concentrate.Filter.Suppress.Screenplay.StopPredictionStatus
  import ExUnit.CaptureLog

  @entries [
    [
      %{route_id: "Red", direction_id: 0, stop_id: 1, suppression_type: "stop"},
      %{route_id: "Red", direction_id: 0, stop_id: 2, suppression_type: "terminal"},
      %{route_id: "Red", direction_id: 1, stop_id: 3, suppression_type: "stop"},
      %{route_id: "Red", direction_id: 1, stop_id: 4, suppression_type: "terminal"},
      %{route_id: "Blue", direction_id: 0, stop_id: 5, suppression_type: "stop"},
      %{route_id: "Blue", direction_id: 1, stop_id: 6, suppression_type: "stop"}
    ]
  ]

  describe "flagged_stops_on_route/3" do
    setup :supervised

    test "returns a MapSet of stop_ids relevant to the route_id, direction_id, and update_type provided" do
      handle_events(@entries, :from, :state)

      assert MapSet.new([1]) == flagged_stops_on_route("Red", 0, "mid_trip")
      assert MapSet.new([2]) == flagged_stops_on_route("Red", 0, "at_terminal")
      assert MapSet.new([3]) == flagged_stops_on_route("Red", 1, "mid_trip")
      assert MapSet.new([4]) == flagged_stops_on_route("Red", 1, "at_terminal")
      assert MapSet.new([5]) == flagged_stops_on_route("Blue", 0, "mid_trip")
      assert MapSet.new([]) == flagged_stops_on_route("Blue", 1, "at_terminal")
    end

    test "returns empty if missing stop_id or direction_id" do
      handle_events(@entries, :from, :state)

      assert [] == flagged_stops_on_route(nil, 1, nil)
      assert [] == flagged_stops_on_route("Red", nil, nil)
    end

    test "logs unsupressed stops when state changes" do
      handle_events(@entries, :from, :state)

      log =
        capture_log(fn ->
          [[_, _ | new_entries]] = @entries
          handle_events([new_entries], :from, :state)
        end)

      assert log =~
               "event=clear_screenplay_prediction_suppression stop_id=1 route_id=Red direction_id=0 suppression_type=stop"

      assert log =~
               "event=clear_screenplay_prediction_suppression stop_id=2 route_id=Red direction_id=0 suppression_type=terminal"

      assert MapSet.new([]) == flagged_stops_on_route("Red", 0, "mid_trip")
      assert MapSet.new([3]) == flagged_stops_on_route("Red", 1, "mid_trip")
      assert MapSet.new([4]) == flagged_stops_on_route("Red", 1, "at_terminal")
      assert MapSet.new([5]) == flagged_stops_on_route("Blue", 0, "mid_trip")
      assert MapSet.new([]) == flagged_stops_on_route("Blue", 1, "at_terminal")
    end

    test "empties state when supplied with empty list" do
      handle_events(@entries, :from, :state)

      log =
        capture_log(fn ->
          handle_events([[]], :from, :state)
        end)

      assert log =~
               "event=clear_screenplay_prediction_suppression stop_id=1 route_id=Red direction_id=0 suppression_type=stop"

      assert log =~
               "event=clear_screenplay_prediction_suppression stop_id=2 route_id=Red direction_id=0 suppression_type=terminal"

      assert log =~
               "event=clear_screenplay_prediction_suppression stop_id=3 route_id=Red direction_id=1 suppression_type=stop"

      assert log =~
               "event=clear_screenplay_prediction_suppression stop_id=4 route_id=Red direction_id=1 suppression_type=terminal"

      assert log =~
               "event=clear_screenplay_prediction_suppression stop_id=5 route_id=Blue direction_id=0 suppression_type=stop"

      assert log =~
               "event=clear_screenplay_prediction_suppression stop_id=6 route_id=Blue direction_id=1 suppression_type=stop"

      assert MapSet.new([]) == flagged_stops_on_route("Red", 0, "mid_trip")
      assert MapSet.new([]) == flagged_stops_on_route("Red", 1, "mid_trip")
      assert MapSet.new([]) == flagged_stops_on_route("Blue", 0, "mid_trip")
      assert MapSet.new([]) == flagged_stops_on_route("Blue", 1, "mid_trip")
    end
  end

  defp supervised(_) do
    start_supervised(Concentrate.Filter.Suppress.Screenplay.StopPredictionStatus)
    :ok
  end
end
