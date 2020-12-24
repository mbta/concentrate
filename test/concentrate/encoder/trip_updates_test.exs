defmodule Concentrate.Encoder.TripUpdatesTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.TestHelpers
  import Concentrate.Encoder.TripUpdates
  import Concentrate.Encoder.GTFSRealtimeHelpers, only: [group: 1]
  alias Concentrate.{TripDescriptor, VehiclePosition, StopTimeUpdate}
  alias Concentrate.Parser.GTFSRealtime

  describe "encode_groups/1" do
    test "order of trip updates doesn't matter" do
      initial = [
        TripDescriptor.new(trip_id: "1"),
        TripDescriptor.new(trip_id: "2"),
        StopTimeUpdate.new(trip_id: "1", arrival_time: 1)
      ]

      decoded = GTFSRealtime.parse(encode_groups(group(initial)), [])

      assert [TripDescriptor.new(trip_id: "1"), StopTimeUpdate.new(trip_id: "1", arrival_time: 1)] ==
               decoded
    end

    test "trips appear in their order, regardless of StopTimeUpdate order" do
      trip_updates = [
        TripDescriptor.new(trip_id: "1"),
        TripDescriptor.new(trip_id: "2"),
        TripDescriptor.new(trip_id: "3")
      ]

      stop_time_updates =
        Enum.shuffle([
          StopTimeUpdate.new(trip_id: "1", arrival_time: 1),
          StopTimeUpdate.new(trip_id: "2", arrival_time: 2),
          StopTimeUpdate.new(trip_id: "3", arrival_time: 3)
        ])

      initial = trip_updates ++ stop_time_updates
      decoded = GTFSRealtime.parse(encode_groups(group(initial)), [])

      assert [
               TripDescriptor.new(trip_id: "1"),
               StopTimeUpdate.new(trip_id: "1", arrival_time: 1),
               TripDescriptor.new(trip_id: "2"),
               StopTimeUpdate.new(trip_id: "2", arrival_time: 2),
               TripDescriptor.new(trip_id: "3"),
               StopTimeUpdate.new(trip_id: "3", arrival_time: 3)
             ] == decoded
    end

    test "trips with only vehicles aren't encoded" do
      initial = [
        TripDescriptor.new(trip_id: "1"),
        VehiclePosition.new(trip_id: "1", latitude: 1, longitude: 1)
      ]

      decoded = GTFSRealtime.parse(encode_groups(group(initial)), [])
      assert decoded == []
    end

    test "trips include part of vehicles" do
      initial = [
        TripDescriptor.new(trip_id: "1"),
        StopTimeUpdate.new(trip_id: "1", arrival_time: 1),
        VehiclePosition.new(
          trip_id: "1",
          latitude: 1,
          longitude: 1,
          id: "id",
          label: "label",
          license_plate: "plate"
        )
      ]

      decoded = :gtfs_realtime_proto.decode_msg(encode_groups(group(initial)), :FeedMessage, [])

      assert %{
               entity: [
                 %{trip_update: %{vehicle: %{id: "id", label: "label", license_plate: "plate"}}}
               ]
             } = decoded
    end

    test "stop time updates with only a boarding status are removed" do
      initial = [
        TripDescriptor.new(trip_id: "1"),
        StopTimeUpdate.new(trip_id: "1", stop_sequence: 1, status: "status"),
        StopTimeUpdate.new(trip_id: "1", stop_sequence: 2, departure_time: 1, status: "boarding"),
        StopTimeUpdate.new(trip_id: "1", stop_sequence: 3, arrival_time: 2),
        TripDescriptor.new(trip_id: "2"),
        StopTimeUpdate.new(trip_id: "2", status: "status")
      ]

      decoded = GTFSRealtime.parse(encode_groups(group(initial)), [])

      assert [
               TripDescriptor.new(trip_id: "1"),
               StopTimeUpdate.new(trip_id: "1", stop_sequence: 2, departure_time: 1),
               StopTimeUpdate.new(trip_id: "1", stop_sequence: 3, arrival_time: 2)
             ] ==
               decoded
    end

    test "decoding and re-encoding tripupdates.pb is a no-op" do
      decoded = GTFSRealtime.parse(File.read!(fixture_path("tripupdates.pb")), [])
      round_tripped = GTFSRealtime.parse(encode_groups(group(decoded)), [])
      assert Enum.sort(round_tripped) == Enum.sort(decoded)
    end

    test "interspersing VehiclePositions doesn't affect the output (with non-matching trips)" do
      decoded = GTFSRealtime.parse(File.read!(fixture_path("tripupdates.pb")), [])

      interspersed =
        Enum.intersperse(
          decoded,
          VehiclePosition.new(trip_id: "non_matching", latitude: 1, longitude: 1)
        )

      round_tripped = GTFSRealtime.parse(encode_groups(group(interspersed)), [])
      assert Enum.sort(round_tripped) == Enum.sort(decoded)
    end

    test "trips with route_pattern_id present don't have that field" do
      initial = [
        TripDescriptor.new(trip_id: "trip", route_pattern_id: "pattern"),
        StopTimeUpdate.new(trip_id: "trip", stop_id: "stop", departure_time: 1)
      ]

      decoded = :gtfs_realtime_proto.decode_msg(encode_groups(group(initial)), :FeedMessage, [])

      %{
        entity: [
          %{trip_update: %{trip: trip}}
        ]
      } = decoded

      refute "route_pattern_id" in Map.keys(trip)
    end

    test "trips updates with timestamp present don't have that field" do
      initial = [
        TripDescriptor.new(trip_id: "trip", timestamp: 1_534_340_406),
        StopTimeUpdate.new(trip_id: "trip", stop_id: "stop", departure_time: 1)
      ]

      decoded = :gtfs_realtime_proto.decode_msg(encode_groups(group(initial)), :FeedMessage, [])

      %{
        entity: [
          %{trip_update: %{trip: trip, timestamp: 1_534_340_406}}
        ]
      } = decoded

      refute "route_pattern_id" in Map.keys(trip)
    end
  end
end
