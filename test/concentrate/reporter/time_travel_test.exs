defmodule Concentrate.Reporter.TimeTravelTest do
  @moduledoc false
  use ExUnit.Case
  import ExUnit.CaptureLog

  alias Concentrate.Reporter.TimeTravel
  alias Concentrate.{StopTimeUpdate, TripDescriptor}

  defp build_trip(timings) do
    td = %TripDescriptor{
      trip_id: "trip",
      start_time: "00:00:00",
      start_date: "20190101"
    }

    stop_time_updates =
      timings
      |> Enum.with_index(1)
      |> Enum.map(fn {{arrival, departure}, sequence} ->
        %StopTimeUpdate{
          trip_id: "trip",
          stop_sequence: sequence,
          arrival_time: arrival,
          departure_time: departure
        }
      end)

    {td, [], stop_time_updates}
  end

  describe "log" do
    test "does not log on linear trips" do
      trip =
        build_trip([
          {nil, 1},
          {2, 3},
          {4, 5},
          {9, 12},
          {15, nil}
        ])

      assert capture_log([level: :warning], fn ->
               TimeTravel.log([trip], nil)
             end) === ""
    end

    test "logs on trips with time travel" do
      trip =
        build_trip([
          {nil, 1},
          {2, 3},
          {4, 10},
          {9, 12},
          {15, nil}
        ])

      assert capture_log([level: :warning], fn ->
               TimeTravel.log([trip], nil)
             end) =~ "time_travel"
    end

    test "does not consider skipped stops time travel" do
      trip =
        build_trip([
          {nil, 1},
          {nil, nil},
          {4, 5}
        ])

      assert capture_log([level: :warning], fn ->
               TimeTravel.log([trip], nil)
             end) === ""
    end
  end
end
