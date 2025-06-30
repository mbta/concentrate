defmodule Concentrate.Filter.Suppress.StopPredictionStatusTest do
  @moduledoc false
  use ExUnit.Case
  import Concentrate.Filter.Suppress.StopPredictionStatus
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

  describe "suppressed_stops_on_route/2" do
    setup :supervised

    test "returns a MapSet of stop_ids with 'stop' suppression type for the given route and direction" do
      handle_events(@entries, :from, :state)

      assert MapSet.new([1]) == suppressed_stops_on_route("Red", 0)
      assert MapSet.new([3]) == suppressed_stops_on_route("Red", 1)
      assert MapSet.new([5]) == suppressed_stops_on_route("Blue", 0)
      assert MapSet.new([6]) == suppressed_stops_on_route("Blue", 1)
    end

    test "returns empty MapSet if missing route_id or direction_id" do
      handle_events(@entries, :from, :state)

      assert MapSet.new() == suppressed_stops_on_route(nil, 1)
      assert MapSet.new() == suppressed_stops_on_route("Red", nil)
    end
  end

  describe "terminals_suppressed/2" do
    setup :supervised

    test "returns a MapSet of stop_ids with 'terminal' suppression type for the given route and direction" do
      handle_events(@entries, :from, :state)

      assert MapSet.new([2]) == terminals_suppressed("Red", 0)
      assert MapSet.new([4]) == terminals_suppressed("Red", 1)
      assert MapSet.new([]) == terminals_suppressed("Blue", 0)
      assert MapSet.new([]) == terminals_suppressed("Blue", 1)
    end

    test "returns empty MapSet if missing route_id or direction_id" do
      handle_events(@entries, :from, :state)

      assert MapSet.new() == terminals_suppressed(nil, 1)
      assert MapSet.new() == terminals_suppressed("Red", nil)
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

      assert MapSet.new([]) == suppressed_stops_on_route("Red", 0)
      assert MapSet.new([]) == terminals_suppressed("Red", 0)

      assert MapSet.new([3]) == suppressed_stops_on_route("Red", 1)
      assert MapSet.new([4]) == terminals_suppressed("Red", 1)
      assert MapSet.new([5]) == suppressed_stops_on_route("Blue", 0)
      assert MapSet.new([6]) == suppressed_stops_on_route("Blue", 1)
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

      assert MapSet.new([]) == suppressed_stops_on_route("Red", 0)
      assert MapSet.new([]) == suppressed_stops_on_route("Red", 1)
      assert MapSet.new([]) == suppressed_stops_on_route("Blue", 0)
      assert MapSet.new([]) == suppressed_stops_on_route("Blue", 1)
      assert MapSet.new([]) == terminals_suppressed("Red", 0)
      assert MapSet.new([]) == terminals_suppressed("Red", 1)
      assert MapSet.new([]) == terminals_suppressed("Blue", 0)
      assert MapSet.new([]) == terminals_suppressed("Blue", 1)
    end
  end

  defp supervised(_) do
    start_supervised(Concentrate.Filter.Suppress.StopPredictionStatus)
    :ok
  end
end
