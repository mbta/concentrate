defmodule Concentrate.GroupFilter.TimeTravelTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Concentrate.GroupFilter.TimeTravel
  alias Concentrate.{TripDescriptor, StopTimeUpdate}

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

  defp trip_stops({_, _, stop_time_updates}) do
    Enum.map(stop_time_updates, & &1.stop_sequence)
  end

  test "does not affect linear trips" do
    expected_trip =
      build_trip([
        {nil, 1},
        {2, 3},
        {4, 5},
        {9, 12},
        {15, nil}
      ])

    {td, vp, stop_time_updates} = expected_trip
    actual_trip = TimeTravel.filter(expected_trip)
    assert {^td, ^vp, stop_time_updates} = actual_trip

    assert trip_stops(actual_trip) == trip_stops(expected_trip)
  end

  test "drops predecing stops when prediction involves going back in time" do
    trip =
      build_trip([
        {nil, 1},
        {2, 3},
        {4, 10},
        {9, 12},
        {15, nil}
      ])

    filtered_trip = TimeTravel.filter(trip)

    assert [4, 5] == trip_stops(filtered_trip)
  end

  test "drops predecing stops when multiple instances of time travel are detected" do
    trip =
      build_trip([
        {nil, 1},
        {2, 3},
        {4, 10},
        {9, 12},
        {15, 20},
        {19, 25}
      ])

    filtered_trip = TimeTravel.filter(trip)

    assert [6] == trip_stops(filtered_trip)
  end
end
