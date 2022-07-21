defmodule Concentrate.Filter.ScheduleBasedVehicleTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Filter.ScheduleBasedVehicle
  alias Concentrate.VehiclePosition

  describe "filter/1" do
    test "a vehicle position with a trip id not ending with schedBasedVehicle is kept" do
      vp = VehiclePosition.new(trip_id: "trip", latitude: 1, longitude: 1)
      assert {:cont, ^vp} = filter(vp)
    end

    test "a vehicle position ending with schedBasedVehicle is removed" do
      vp = VehiclePosition.new(trip_id: "trip_schedBasedVehicle", latitude: 1, longitude: 1)
      assert :skip = filter(vp)
    end

    test "a vehicle position is not removed if no suffix matches are provided" do
      vp = VehiclePosition.new(trip_id: "trip_schedBasedVehicle", latitude: 1, longitude: 1)
      assert {:cont, ^vp} = filter(vp, [])
    end

    test "a vehicle position ending with any supplied suffix list is removed" do
      vp1 = VehiclePosition.new(trip_id: "trip_suffix_1", latitude: 1, longitude: 1)
      vp2 = VehiclePosition.new(trip_id: "trip_suffix_2", latitude: 1, longitude: 1)
      vp3 = VehiclePosition.new(trip_id: "trip_suffix_3", latitude: 1, longitude: 1)
      vp4 = VehiclePosition.new(trip_id: "trip_suffix_4", latitude: 1, longitude: 1)
      assert :skip = filter(vp1, ["suffix_1", "suffix_2", "suffix_3"])
      assert :skip = filter(vp2, ["suffix_1", "suffix_2", "suffix_3"])
      assert :skip = filter(vp3, ["suffix_1", "suffix_2", "suffix_3"])
      assert {:cont, ^vp4} = filter(vp4, ["suffix_1", "suffix_2", "suffix_2"])
    end

    test "other values are returned as-is" do
      assert {:cont, :value} = filter(:value)
    end
  end
end
