defmodule Concentrate.GroupFilter.ScheduledStopTimesTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Concentrate.GroupFilter.ScheduledStopTimes
  alias Concentrate.{TripDescriptor, StopTimeUpdate}

  defmodule FakeStopTimes do
    def arrival_departure("trip1", 10, {2022, 1, 1}), do: {1_610_000_000, 1_610_000_001}
    def arrival_departure("trip1", 20, {2022, 1, 1}), do: {1_620_000_000, 1_620_000_001}
    def arrival_departure("trip1", 30, {2022, 1, 1}), do: {1_630_000_000, 1_630_000_001}
    def arrival_departure(_, _, _), do: :unknown
  end

  # see config/test.exs
  @on_time_status "on time"
  @other_status "delayed"

  defp filter(trip_group), do: ScheduledStopTimes.filter(trip_group, FakeStopTimes)

  describe "filter/2" do
    test "fills in missing times from the static schedule when status is a specific value" do
      trip = TripDescriptor.new(trip_id: "trip1", start_date: {2022, 1, 1})
      stu1 = StopTimeUpdate.new(trip_id: "trip1", stop_sequence: 0, status: @on_time_status)
      stu2 = StopTimeUpdate.new(trip_id: "trip1", stop_sequence: 10, status: @on_time_status)
      stu3 = StopTimeUpdate.new(trip_id: "trip1", stop_sequence: 20, status: @other_status)

      new_stu2 =
        StopTimeUpdate.new(
          trip_id: "trip1",
          stop_sequence: 10,
          status: @on_time_status,
          arrival_time: 1_610_000_000,
          departure_time: 1_610_000_001
        )

      assert filter({trip, [], [stu1, stu2, stu3]}) == {trip, [], [stu1, new_stu2, stu3]}
    end

    test "does not change stop time updates with existing arrival or departure times" do
      trip_group =
        {TripDescriptor.new(trip_id: "trip1", start_date: nil), [],
         [
           StopTimeUpdate.new(
             trip_id: "trip1",
             stop_sequence: 10,
             status: @on_time_status,
             arrival_time: 1_610_000_123
           ),
           StopTimeUpdate.new(
             trip_id: "trip1",
             stop_sequence: 10,
             status: @on_time_status,
             departure_time: 1_610_000_123
           )
         ]}

      assert filter(trip_group) == trip_group
    end

    test "passes through if the trip has no `start_date`" do
      trip_group =
        {TripDescriptor.new(trip_id: "trip1", start_date: nil), [],
         [StopTimeUpdate.new(trip_id: "trip1")]}

      assert filter(trip_group) == trip_group
    end

    test "passes through if no trip descriptor is available" do
      trip_group = {nil, [], [StopTimeUpdate.new(trip_id: "trip1")]}

      assert filter(trip_group) == trip_group
    end
  end
end
