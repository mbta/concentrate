defmodule Concentrate.Filter.Suppress.StopPredictionStatusTest do
  @moduledoc false
  use ExUnit.Case
  import Concentrate.Filter.Suppress.StopPredictionStatus
  import ExUnit.CaptureLog

  @entries [
    %{route_id: "Red", direction_id: 0, stop_id: 1},
    %{route_id: "Red", direction_id: 0, stop_id: 2},
    %{route_id: "Red", direction_id: 1, stop_id: 3},
    %{route_id: "Red", direction_id: 1, stop_id: 4},
    %{route_id: "Blue", direction_id: 0, stop_id: 5},
    %{route_id: "Blue", direction_id: 1, stop_id: 6}
  ]

  describe "flagged_stops_on_route/2" do
    setup :supervised

    test "retuns a MapSet of stop_ids relevant to the route_id and direction_id provided" do
      handle_events(@entries, :from, :state)

      assert MapSet.new([1, 2]) == flagged_stops_on_route("Red", 0)
      assert MapSet.new([3, 4]) == flagged_stops_on_route("Red", 1)
      assert MapSet.new([5]) == flagged_stops_on_route("Blue", 0)
      assert MapSet.new([6]) == flagged_stops_on_route("Blue", 1)
    end

    test "returns nil if missing stop_id or direction_id" do
      handle_events(@entries, :from, :state)

      assert nil == flagged_stops_on_route(nil, 1)
      assert nil == flagged_stops_on_route("Red", nil)
    end

    test "logs unsupressed stops when state changes" do
      handle_events(@entries, :from, :state)

      log =
        capture_log(fn ->
          [_, _ | new_entries] = @entries
          handle_events(new_entries, :from, :state)
        end)

      assert log =~
               "Cleared prediction suppression for stop_id=1 route_id=Red direction_id=0 based on RTS feed"

      assert log =~
               "Cleared prediction suppression for stop_id=2 route_id=Red direction_id=0 based on RTS feed"

      assert MapSet.new([]) == flagged_stops_on_route("Red", 0)
      assert MapSet.new([3, 4]) == flagged_stops_on_route("Red", 1)
      assert MapSet.new([5]) == flagged_stops_on_route("Blue", 0)
      assert MapSet.new([6]) == flagged_stops_on_route("Blue", 1)
    end

    test "empties state when supplied with :empty list" do
      handle_events(@entries, :from, :state)

      log =
        capture_log(fn ->
          handle_events([:empty], :from, :state)
        end)

      assert log =~
               "Cleared prediction suppression for stop_id=1 route_id=Red direction_id=0 based on RTS feed"

      assert log =~
               "Cleared prediction suppression for stop_id=2 route_id=Red direction_id=0 based on RTS feed"

      assert log =~
               "Cleared prediction suppression for stop_id=3 route_id=Red direction_id=1 based on RTS feed"

      assert log =~
               "Cleared prediction suppression for stop_id=4 route_id=Red direction_id=1 based on RTS feed"

      assert log =~
               "Cleared prediction suppression for stop_id=5 route_id=Blue direction_id=0 based on RTS feed"

      assert log =~
               "Cleared prediction suppression for stop_id=6 route_id=Blue direction_id=1 based on RTS feed"

      assert MapSet.new([]) == flagged_stops_on_route("Red", 0)
      assert MapSet.new([]) == flagged_stops_on_route("Red", 1)
      assert MapSet.new([]) == flagged_stops_on_route("Blue", 0)
      assert MapSet.new([]) == flagged_stops_on_route("Blue", 1)
    end
  end

  defp supervised(_) do
    start_supervised(Concentrate.Filter.Suppress.StopPredictionStatus)
    :ok
  end
end
