defmodule Concentrate.Encoder.VehiclePositionsTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.TestHelpers
  import Concentrate.Encoder.VehiclePositions
  import Concentrate.Encoder.GTFSRealtimeHelpers, only: [group: 1]
  alias Concentrate.{FeedUpdate, StopTimeUpdate, TripDescriptor, VehiclePosition}
  alias Concentrate.Parser.GTFSRealtime

  describe "encode/1" do
    test "ignores TripUpdates without a matching vehicle" do
      data = [
        TripDescriptor.new(trip_id: "trip"),
        TripDescriptor.new(trip_id: "real_trip"),
        StopTimeUpdate.new(trip_id: "real_trip"),
        VehiclePosition.new(trip_id: "real_trip", latitude: 1, longitude: 2)
      ]

      assert [%TripDescriptor{}, %VehiclePosition{}] = round_trip(data)
    end

    test "can handle a vehicle w/o a trip" do
      data = [
        trip = TripDescriptor.new(trip_id: "trip"),
        vehicle = VehiclePosition.new(latitude: 1.0, longitude: 1.0, status: :IN_TRANSIT_TO),
        vehicle_no_trip =
          VehiclePosition.new(
            trip_id: "trip",
            latitude: 2.0,
            longitude: 2.0,
            status: :IN_TRANSIT_TO
          )
      ]

      # the trip and trip vehicle are re-arranged in the output
      assert Enum.sort(round_trip(data)) == Enum.sort([trip, vehicle, vehicle_no_trip])
    end

    test "uses the vehicle's ID as the entity ID, or the trip ID, or unique data" do
      data = [
        TripDescriptor.new(trip_id: "trip"),
        VehiclePosition.new(id: "y1234", trip_id: "trip", latitude: 1, longitude: 1),
        TripDescriptor.new(trip_id: "a5678"),
        VehiclePosition.new(trip_id: "a5678", latitude: 1, longitude: 1),
        VehiclePosition.new(latitude: 1, longitude: 1)
      ]

      encoded = encode_groups(group(data))
      proto = :gtfs_realtime_proto.decode_msg(encoded, :FeedMessage)

      assert %{
               entity: [
                 %{id: binary_id},
                 %{id: "a5678"},
                 %{id: "y1234"}
               ]
             } = proto

      assert is_binary(binary_id)
    end

    test "vehicles with a non-matching trip ID generate a fake TripDescriptor" do
      data = [
        VehiclePosition.new(
          trip_id: "trip",
          latitude: 1.0,
          longitude: 1.0,
          status: :IN_TRANSIT_TO
        )
      ]

      assert round_trip(data) ==
               [TripDescriptor.new(trip_id: "trip", schedule_relationship: :UNSCHEDULED)] ++ data
    end

    test "order of trip updates doesn't matter" do
      initial = [
        TripDescriptor.new(trip_id: "1"),
        TripDescriptor.new(trip_id: "2"),
        VehiclePosition.new(trip_id: "1", latitude: 1.0, longitude: 1.0)
      ]

      decoded = round_trip(initial)

      assert [
               TripDescriptor.new(trip_id: "1"),
               VehiclePosition.new(
                 trip_id: "1",
                 latitude: 1.0,
                 longitude: 1.0,
                 status: :IN_TRANSIT_TO
               )
             ] == decoded
    end

    test "trips appear in their order, regardless of VehiclePosition order" do
      trip_updates = [
        TripDescriptor.new(trip_id: "1"),
        TripDescriptor.new(trip_id: "2"),
        TripDescriptor.new(trip_id: "3")
      ]

      stop_time_updates =
        Enum.shuffle([
          VehiclePosition.new(trip_id: "1", latitude: 1.0, longitude: 1.0),
          VehiclePosition.new(trip_id: "2", latitude: 1.0, longitude: 1.0),
          VehiclePosition.new(trip_id: "3", latitude: 1.0, longitude: 1.0)
        ])

      initial = trip_updates ++ stop_time_updates
      decoded = round_trip(initial)

      assert [
               TripDescriptor.new(trip_id: "1"),
               VehiclePosition.new(
                 trip_id: "1",
                 latitude: 1.0,
                 longitude: 1.0,
                 status: :IN_TRANSIT_TO
               ),
               TripDescriptor.new(trip_id: "2"),
               VehiclePosition.new(
                 trip_id: "2",
                 latitude: 1.0,
                 longitude: 1.0,
                 status: :IN_TRANSIT_TO
               ),
               TripDescriptor.new(trip_id: "3"),
               VehiclePosition.new(
                 trip_id: "3",
                 latitude: 1.0,
                 longitude: 1.0,
                 status: :IN_TRANSIT_TO
               )
             ] == decoded
    end

    test "includes occupancy data if present" do
      data = [
        TripDescriptor.new(trip_id: "trip", vehicle_id: "y2"),
        VehiclePosition.new(
          trip_id: "trip",
          id: "y2",
          latitude: 2,
          longitude: 2,
          status: :IN_TRANSIT_TO,
          occupancy_status: :FULL,
          occupancy_percentage: 101
        )
      ]

      assert data == round_trip(data)
    end

    test "multi_carriage_details does not get stomped by pb encoder" do
      data = [
        TripDescriptor.new(trip_id: "trip", vehicle_id: "3022"),
        VehiclePosition.new(
          trip_id: "trip",
          id: "3022",
          latitude: 2,
          longitude: 2,
          status: :IN_TRANSIT_TO,
          multi_carriage_details: [
            %{
              label: "3022",
              carriage_sequence: 1,
              occupancy_status: :MANY_SEATS_AVAILABLE,
              occupancy_percentage: 10
            },
            %{
              label: "3021",
              carriage_sequence: 2,
              occupancy_status: :FEW_SEATS_AVAILABLE,
              occupancy_percentage: 25
            }
          ]
        )
      ]

      assert data == round_trip(data)
    end

    test "decoding and re-encoding vehiclepositions.pb is a no-op" do
      decoded =
        FeedUpdate.updates(
          GTFSRealtime.parse(File.read!(fixture_path("vehiclepositions.pb")), [])
        )

      assert Enum.sort(round_trip(decoded)) == Enum.sort(decoded)
    end

    test "filters non-revenue trips" do
      data = [
        TripDescriptor.new(trip_id: "one", vehicle_id: "y1", revenue: false),
        VehiclePosition.new(
          trip_id: "one",
          id: "y1",
          latitude: 1,
          longitude: 1,
          status: :IN_TRANSIT_TO
        )
      ]

      assert [] == round_trip(data)
    end
  end

  defp round_trip(data) do
    # return the result of decoding the encoded data
    data
    |> group
    |> encode_groups()
    |> GTFSRealtime.parse([])
    |> FeedUpdate.updates()
  end
end
