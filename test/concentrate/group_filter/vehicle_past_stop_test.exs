defmodule Concentrate.GroupFilter.VehiclePastStopTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.GroupFilter.VehiclePastStop
  alias Concentrate.Encoder.TripGroup
  alias Concentrate.{StopTimeUpdate, TripDescriptor, VehiclePosition}

  describe "filter/1" do
    test "removes StopTimeUpdates if they come after the vehicle's sequence" do
      vp = VehiclePosition.new(trip_id: "trip", stop_sequence: 5, latitude: 1, longitude: 1)

      stus = [
        StopTimeUpdate.new(trip_id: "trip", stop_sequence: 4),
        StopTimeUpdate.new(trip_id: "trip", stop_sequence: 5),
        StopTimeUpdate.new(trip_id: "trip")
      ]

      group = %TripGroup{td: TripDescriptor.new([]), vps: [vp], stus: stus}
      expected_stus = Enum.drop(stus, 1)
      %TripGroup{vps: [^vp], stus: actual_stus} = filter(group)
      assert actual_stus == expected_stus
    end

    test "leaves the stops alone if the vehicle doesn't have stop sequence" do
      td = TripDescriptor.new([])
      vp = VehiclePosition.new(latitude: 1, longitude: 1)

      stus = [
        StopTimeUpdate.new(stop_sequence: 4)
      ]

      group = %TripGroup{td: td, vps: [vp], stus: stus}
      assert filter(group) == group
    end
  end
end
