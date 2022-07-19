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

    test "other values are returned as-is" do
      assert {:cont, :value} = filter(:value)
    end
  end
end
