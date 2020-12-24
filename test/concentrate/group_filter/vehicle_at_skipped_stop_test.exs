defmodule Concentrate.GroupFilter.VehicleAtSkippedStopTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.GroupFilter.VehicleAtSkippedStop
  alias Concentrate.{TripDescriptor, VehiclePosition, StopTimeUpdate}

  describe "filter/1" do
    test "if the vehicle's stop_id is SKIPPED, change to the next stop" do
      td = TripDescriptor.new([])

      vp =
        VehiclePosition.new(
          latitude: 1,
          longitude: 1,
          status: :STOPPED_AT,
          stop_sequence: 2,
          stop_id: "2"
        )

      stus = [
        StopTimeUpdate.new(stop_id: "1", stop_sequence: 1),
        StopTimeUpdate.new(stop_id: "2", stop_sequence: 2, schedule_relationship: :SKIPPED),
        StopTimeUpdate.new(stop_id: "3", stop_sequence: 3, schedule_relationship: :SKIPPED),
        StopTimeUpdate.new(stop_id: "4", stop_sequence: 4),
        StopTimeUpdate.new(stop_id: "4", stop_sequence: 5)
      ]

      group = {td, [vp], stus}
      {^td, [new_vp], ^stus} = filter(group)
      assert VehiclePosition.stop_sequence(new_vp) == 4
      assert VehiclePosition.stop_id(new_vp) == "4"
      assert VehiclePosition.status(new_vp) == :IN_TRANSIT_TO
    end

    test "if the vehicle's stop_id is the last non-skipped stop, removes it" do
      td = TripDescriptor.new([])

      vp =
        VehiclePosition.new(
          latitude: 1,
          longitude: 1,
          status: :STOPPED_AT,
          stop_sequence: 2,
          stop_id: "2"
        )

      stus = [
        StopTimeUpdate.new(stop_id: "1", stop_sequence: 1),
        StopTimeUpdate.new(stop_id: "2", stop_sequence: 2, schedule_relationship: :SKIPPED)
      ]

      group = {td, [vp], stus}
      {^td, [new_vp], ^stus} = filter(group)
      assert VehiclePosition.stop_sequence(new_vp) == nil
      assert VehiclePosition.stop_id(new_vp) == nil
      assert VehiclePosition.status(new_vp) == :IN_TRANSIT_TO
    end

    test "if the vehicle isn't at a SKIPPED stop, does nothing" do
      td = TripDescriptor.new([])

      vp =
        VehiclePosition.new(
          latitude: 1,
          longitude: 1,
          status: :STOPPED_AT,
          stop_sequence: 1,
          stop_id: "1"
        )

      stus = [
        StopTimeUpdate.new(stop_id: "1", stop_sequence: 1)
      ]

      group = {td, [vp], stus}
      assert filter(group) == group
    end

    test "if the vehicle's stop doesn't match the updates, does nothing" do
      td = TripDescriptor.new([])

      vp =
        VehiclePosition.new(
          latitude: 1,
          longitude: 1,
          status: :STOPPED_AT,
          stop_sequence: 5,
          stop_id: "5"
        )

      stus = [
        StopTimeUpdate.new(stop_id: "1", stop_sequence: 1)
      ]

      group = {td, [vp], stus}
      assert filter(group) == group
    end

    test "if the vehicle doesn't have a stop does nothing" do
      td = TripDescriptor.new([])

      vp =
        VehiclePosition.new(
          latitude: 1,
          longitude: 1
        )

      stus = [
        StopTimeUpdate.new(stop_id: "1", stop_sequence: 1)
      ]

      group = {td, [vp], stus}
      assert filter(group) == group
    end
  end
end
