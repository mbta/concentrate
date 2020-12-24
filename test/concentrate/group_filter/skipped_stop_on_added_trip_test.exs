defmodule Concentrate.Filter.SkippedStopOnAddedTripTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.GroupFilter.SkippedStopOnAddedTrip
  alias Concentrate.{TripDescriptor, StopTimeUpdate}

  @trip_id "trip"

  describe "filter/2" do
    test "removes SKIPPED updates from ADDED trips" do
      td = TripDescriptor.new(trip_id: @trip_id, schedule_relationship: :ADDED)
      stu = StopTimeUpdate.new(trip_id: @trip_id, schedule_relationship: :SKIPPED)
      assert {^td, [], []} = filter({td, [], [stu]})
    end

    test "removes SKIPPED updates from UNSCHEDULED trips" do
      td = TripDescriptor.new(trip_id: @trip_id, schedule_relationship: :UNSCHEDULED)
      stu = StopTimeUpdate.new(trip_id: @trip_id, schedule_relationship: :SKIPPED)
      assert {^td, [], []} = filter({td, [], [stu]})
    end

    test "keeps SKIPPED updates from normal trips" do
      td = TripDescriptor.new(trip_id: @trip_id)
      stu = StopTimeUpdate.new(trip_id: @trip_id, schedule_relationship: :SKIPPED)
      assert {^td, [], [^stu]} = filter({td, [], [stu]})
    end

    test "keeps normal updates from ADDED trips" do
      td = TripDescriptor.new(trip_id: @trip_id, schedule_relationship: :ADDED)
      stu = StopTimeUpdate.new(trip_id: @trip_id)
      assert {^td, [], [^stu]} = filter({td, [], [stu]})
    end

    test "other values are returned as-is" do
      assert filter(:value) == :value
    end
  end
end
