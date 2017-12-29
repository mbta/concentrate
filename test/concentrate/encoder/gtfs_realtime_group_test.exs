defmodule Concentrate.Encoder.GTFSRealtimeGroupTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Encoder.GTFSRealtimeGroup
  alias Concentrate.{TripUpdate, VehiclePosition, StopTimeUpdate}

  describe "group/1" do
    test "groups items by their trip ID" do
      tu = TripUpdate.new(trip_id: "trip")
      stu = StopTimeUpdate.new(trip_id: "trip", stop_sequence: 1)
      stu2 = StopTimeUpdate.new(trip_id: "trip", stop_sequence: 2)
      vehicle = VehiclePosition.new(trip_id: "trip", latitude: 1, longitude: 1)
      vehicle_no_trip = VehiclePosition.update(vehicle, trip_id: nil)

      parsed = [
        tu,
        vehicle,
        vehicle_no_trip,
        stu,
        stu2
      ]

      expected = [
        {tu, [vehicle], [stu, stu2]},
        {nil, [vehicle_no_trip], []}
      ]

      actual = group(parsed)
      assert actual == expected
    end

    test "trip updates without a trip ID are ignored" do
      tu = TripUpdate.new([])
      assert [] = group([tu])
    end

    test "out-of-order updates are merged" do
      tu = TripUpdate.new(trip_id: "trip")
      stu = StopTimeUpdate.new(trip_id: "trip", stop_sequence: 1)
      vehicle = VehiclePosition.new(trip_id: "trip", latitude: 1, longitude: 1)

      parsed = [
        stu,
        vehicle,
        tu
      ]

      expected = [{tu, [vehicle], [stu]}]

      actual = group(parsed)
      assert actual == expected
    end

    test "trip updates without a vehicle or stop time are ignored" do
      tu = TripUpdate.new(trip_id: "trip")
      assert [] = group([tu])
    end
  end
end
