defmodule Concentrate.Filter.SkippedStopOnAddedTripTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Filter.SkippedStopOnAddedTrip
  alias Concentrate.{TripUpdate, StopTimeUpdate}

  @trip_id "trip"

  setup do
    {:ok, %{state: init()}}
  end

  describe "filter/2" do
    test "removes SKIPPED updates from ADDED trips", %{state: state} do
      {:cont, _, state} =
        filter(TripUpdate.new(trip_id: @trip_id, schedule_relationship: :ADDED), state)

      assert {:skip, ^state} =
               filter(
                 StopTimeUpdate.new(trip_id: @trip_id, schedule_relationship: :SKIPPED),
                 state
               )
    end

    test "removes SKIPPED updates from UNSCHEDULED trips", %{state: state} do
      {:cont, _, state} =
        filter(TripUpdate.new(trip_id: @trip_id, schedule_relationship: :UNSCHEDULED), state)

      assert {:skip, ^state} =
               filter(
                 StopTimeUpdate.new(trip_id: @trip_id, schedule_relationship: :SKIPPED),
                 state
               )
    end

    test "keeps SKIPPED updates from normal trips", %{state: state} do
      {:cont, _, state} = filter(TripUpdate.new(trip_id: @trip_id), state)

      stu = StopTimeUpdate.new(trip_id: @trip_id, schedule_relationship: :SKIPPED)
      assert {:cont, _, ^state} = filter(stu, state)
    end

    test "keeps normal updates from ADDED trips", %{state: state} do
      {:cont, _, state} =
        filter(TripUpdate.new(trip_id: @trip_id, schedule_relationship: :ADDED), state)

      stu = StopTimeUpdate.new(trip_id: @trip_id)
      assert {:cont, ^stu, ^state} = filter(stu, state)
    end

    test "other values are returned as-is", %{state: state} do
      assert {:cont, :value, _} = filter(:value, state)
    end
  end
end
