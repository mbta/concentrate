defmodule Concentrate.GroupFilter.VehiclePastStopTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.GroupFilter.VehiclePastStop
  alias Concentrate.{TripDescriptor, VehiclePosition, StopTimeUpdate}

  describe "filter/1" do
    test "removes StopTimeUpdates if they come after the vehicle's sequence" do
      vp = VehiclePosition.new(trip_id: "trip", stop_sequence: 5, latitude: 1, longitude: 1)

      stus = [
        StopTimeUpdate.new(trip_id: "trip", stop_sequence: 4),
        StopTimeUpdate.new(trip_id: "trip", stop_sequence: 5),
        StopTimeUpdate.new(trip_id: "trip")
      ]

      expected = Enum.drop(stus, 1)
      {_, [^vp], actual} = filter({TripDescriptor.new([]), [vp], stus})
      assert actual == expected
    end

    test "leaves the stops alone if the vehicle doesn't have stop sequence" do
      td = TripDescriptor.new([])
      vp = VehiclePosition.new(latitude: 1, longitude: 1)

      stus = [
        StopTimeUpdate.new(stop_sequence: 4)
      ]

      group = {td, [vp], stus}
      assert filter(group) == group
    end

    test "other values are returned as-is" do
      assert filter(:value) == :value
    end
  end
end
