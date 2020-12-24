defmodule Concentrate.Encoder.GTFSRealtimeHelpersTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Encoder.GTFSRealtimeHelpers
  alias Concentrate.{TripDescriptor, VehiclePosition, StopTimeUpdate}

  doctest Concentrate.Encoder.GTFSRealtimeHelpers

  describe "group/1" do
    test "groups items by their trip ID" do
      td = TripDescriptor.new(trip_id: "trip")
      stu = StopTimeUpdate.new(trip_id: "trip", stop_sequence: 1)
      stu2 = StopTimeUpdate.new(trip_id: "trip", stop_sequence: 2)
      vehicle = VehiclePosition.new(trip_id: "trip", latitude: 1, longitude: 1)
      vehicle_no_trip = VehiclePosition.update(vehicle, trip_id: nil)

      parsed = [
        td,
        vehicle,
        vehicle_no_trip,
        stu,
        stu2
      ]

      expected = [
        {nil, [vehicle_no_trip], []},
        {td, [vehicle], [stu, stu2]}
      ]

      actual = Enum.sort(group(parsed))
      assert actual == expected
    end

    test "trip updates without a trip ID are ignored" do
      td = TripDescriptor.new([])
      assert [] = group([td])
    end

    test "out-of-order updates are merged" do
      td = TripDescriptor.new(trip_id: "trip")
      stu = StopTimeUpdate.new(trip_id: "trip", stop_sequence: 1)
      vehicle = VehiclePosition.new(trip_id: "trip", latitude: 1, longitude: 1)

      parsed = [
        stu,
        vehicle,
        td
      ]

      expected = [{td, [vehicle], [stu]}]

      actual = group(parsed)
      assert actual == expected
    end

    test "non-CANCELED trip updates without a vehicle or stop time are ignored" do
      for relationship <- ~w(SCHEDULED ADDED)a do
        td = TripDescriptor.new(trip_id: "trip", schedule_relationship: relationship)
        assert {relationship, []} == {relationship, group([td])}
      end
    end

    test "CANCELED trip updates without a vehicle or stop time are kept" do
      td = TripDescriptor.new(trip_id: "trip", schedule_relationship: :CANCELED)
      assert [{^td, [], []}] = group([td])
    end
  end
end
