defmodule Concentrate.Filter.FilterTripUpdateVehiclesTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Filter.FilterTripUpdateVehicles
  alias Concentrate.TripDescriptor

  describe "filter/1" do
    test "a trip descriptor with a vehicle id not ending with schedBasedVehicle is not changed" do
      td = TripDescriptor.new(trip_id: "trip", vehicle_id: "vehicle1")
      assert {:cont, ^td} = filter(td)
    end

    test "a trip descriptor with vehicle id ending with schedBasedVehicle has the vehicle_id removed" do
      td = TripDescriptor.new(trip_id: "trip", vehicle_id: "vehicle_schedBasedVehicle")

      assert {:cont, %TripDescriptor{trip_id: "trip", vehicle_id: nil}} = filter(td)
    end

    test "a trip descriptor with no vehicle id passes through" do
      td = TripDescriptor.new(trip_id: "trip", vehicle_id: nil)

      assert {:cont, %TripDescriptor{trip_id: "trip", vehicle_id: nil}} = filter(td)
    end

    test "a trip descriptor is not affected if no suffix matches are provided" do
      td = TripDescriptor.new(trip_id: "trip", vehicle_id: "vehicle_schedBasedVehicle")
      assert {:cont, ^td} = filter(td, [])
    end

    test "a trip descriptor ending with any supplied suffix list has the vehicle_id removed" do
      td1 = TripDescriptor.new(trip_id: "trip1", vehicle_id: "vehicle_suffix_1")
      td2 = TripDescriptor.new(trip_id: "trip2", vehicle_id: "vehicle_suffix_2")
      td3 = TripDescriptor.new(trip_id: "trip3", vehicle_id: "vehicle_suffix_3")
      td4 = TripDescriptor.new(trip_id: "trip4", vehicle_id: "vehicle_suffix_4")

      assert {:cont, %TripDescriptor{trip_id: "trip1", vehicle_id: nil}} =
               filter(td1, ["suffix_1", "suffix_2", "suffix_3"])

      assert {:cont, %TripDescriptor{trip_id: "trip2", vehicle_id: nil}} =
               filter(td2, ["suffix_1", "suffix_2", "suffix_3"])

      assert {:cont, %TripDescriptor{trip_id: "trip3", vehicle_id: nil}} =
               filter(td3, ["suffix_1", "suffix_2", "suffix_3"])

      assert {:cont, ^td4} = filter(td4, ["suffix_1", "suffix_2", "suffix_3"])
    end

    test "other values are returned as-is" do
      assert {:cont, :value} = filter(:value)
    end
  end
end
