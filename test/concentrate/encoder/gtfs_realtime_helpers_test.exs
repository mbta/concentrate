defmodule Concentrate.Encoder.GTFSRealtimeHelpersTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Encoder.GTFSRealtimeHelpers
  alias Concentrate.Encoder.TripGroup
  alias Concentrate.{StopTimeUpdate, TripDescriptor, TripProperties, VehiclePosition}

  doctest Concentrate.Encoder.GTFSRealtimeHelpers

  describe "group/1" do
    test "groups items by their trip ID" do
      td_a = TripDescriptor.new(trip_id: "trip-A")
      td_b = TripDescriptor.new(trip_id: "trip-B")
      stu_1 = StopTimeUpdate.new(trip_id: "trip-A", stop_sequence: 1)
      stu_2 = StopTimeUpdate.new(trip_id: "trip-A", stop_sequence: 2)
      stu_3 = StopTimeUpdate.new(trip_id: "trip-B", stop_sequence: 1)
      tp = TripProperties.new(trip_id: "trip-B", trip_headsign: "boop")
      vehicle = VehiclePosition.new(trip_id: "trip-A", latitude: 1, longitude: 1)
      vehicle_no_trip = VehiclePosition.update(vehicle, trip_id: nil)

      parsed = [
        td_a,
        vehicle,
        vehicle_no_trip,
        stu_1,
        stu_2,
        td_b,
        stu_3,
        tp
      ]

      expected = [
        %TripGroup{td: nil, vps: [vehicle_no_trip], stus: []},
        %TripGroup{td: td_a, vps: [vehicle], stus: [stu_1, stu_2]},
        %TripGroup{td: td_b, vps: [], stus: [stu_3], tp: tp}
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

      expected = [%TripGroup{td: td, vps: [vehicle], stus: [stu]}]

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
      assert [%TripGroup{td: ^td, vps: [], stus: []}] = group([td])
    end
  end
end
