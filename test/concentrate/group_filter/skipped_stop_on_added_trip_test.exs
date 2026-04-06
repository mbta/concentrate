defmodule Concentrate.Filter.SkippedStopOnAddedTripTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Concentrate.Encoder.TripGroup
  import Concentrate.GroupFilter.SkippedStopOnAddedTrip
  alias Concentrate.{StopTimeUpdate, TripDescriptor}

  @trip_id "trip"

  describe "filter/2" do
    test "removes SKIPPED updates from ADDED trips" do
      td = TripDescriptor.new(trip_id: @trip_id, schedule_relationship: :ADDED)
      stu = StopTimeUpdate.new(trip_id: @trip_id, schedule_relationship: :SKIPPED)
      assert %TripGroup{td: ^td, stus: []} = filter(%TripGroup{td: td, stus: [stu]})
    end

    test "removes SKIPPED updates from UNSCHEDULED trips" do
      td = TripDescriptor.new(trip_id: @trip_id, schedule_relationship: :UNSCHEDULED)
      stu = StopTimeUpdate.new(trip_id: @trip_id, schedule_relationship: :SKIPPED)
      assert %TripGroup{td: ^td, stus: []} = filter(%TripGroup{td: td, stus: [stu]})
    end

    test "keeps SKIPPED updates from normal trips" do
      td = TripDescriptor.new(trip_id: @trip_id)
      stu = StopTimeUpdate.new(trip_id: @trip_id, schedule_relationship: :SKIPPED)
      assert %TripGroup{td: ^td, stus: [^stu]} = filter(%TripGroup{td: td, stus: [stu]})
    end

    test "keeps normal updates from ADDED trips" do
      td = TripDescriptor.new(trip_id: @trip_id, schedule_relationship: :ADDED)
      stu = StopTimeUpdate.new(trip_id: @trip_id)
      assert %TripGroup{td: ^td, stus: [^stu]} = filter(%TripGroup{td: td, stus: [stu]})
    end

    test "keeps stus with passthough_times from ADDED trips" do
      td = TripDescriptor.new(trip_id: @trip_id, schedule_relationship: :ADDED)

      stu =
        StopTimeUpdate.new(
          trip_id: @trip_id,
          schedule_relationship: :SKIPPED,
          passthrough_time: 500
        )

      assert %TripGroup{td: ^td, stus: [^stu]} = filter(%TripGroup{td: td, stus: [stu]})
    end

    test "keeps stus with passthough_times from UNSCHEDULED trips" do
      td = TripDescriptor.new(trip_id: @trip_id, schedule_relationship: :UNSCHEDULED)

      stu =
        StopTimeUpdate.new(
          trip_id: @trip_id,
          schedule_relationship: :SKIPPED,
          passthrough_time: 500
        )

      assert %TripGroup{td: ^td, stus: [^stu]} = filter(%TripGroup{td: td, stus: [stu]})
    end
  end
end
