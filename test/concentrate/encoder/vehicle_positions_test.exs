defmodule Concentrate.Encoder.VehiclePositionsTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.TestHelpers
  import Concentrate.Encoder.VehiclePositions
  alias Concentrate.{TripUpdate, VehiclePosition, StopTimeUpdate}
  alias Concentrate.Parser.GTFSRealtime

  describe "encode/1" do
    test "ignores TripUpdates without a matching vehicle" do
      data = [
        TripUpdate.new(trip_id: "trip"),
        TripUpdate.new(trip_id: "real_trip"),
        StopTimeUpdate.new(trip_id: "real_trip"),
        VehiclePosition.new(trip_id: "real_trip", latitude: 1, longitude: 2)
      ]

      assert [%TripUpdate{}, %VehiclePosition{}] = round_trip(data)
    end

    test "can handle a vehicle w/o a trip" do
      data = [
        trip = TripUpdate.new(trip_id: "trip"),
        no_trip_vehicle = VehiclePosition.new(latitude: 1.0, longitude: 1.0),
        trip_vehicle = VehiclePosition.new(trip_id: "trip", latitude: 2.0, longitude: 2.0)
      ]

      # the trip and trip vehicle are re-arranged in the output
      assert round_trip(data) == [
               trip,
               trip_vehicle,
               no_trip_vehicle
             ]
    end

    test "order of trip updates doesn't matter" do
      initial = [
        TripUpdate.new(trip_id: "1"),
        TripUpdate.new(trip_id: "2"),
        VehiclePosition.new(trip_id: "1", latitude: 1.0, longitude: 1.0)
      ]

      decoded = round_trip(initial)

      assert [
               TripUpdate.new(trip_id: "1"),
               VehiclePosition.new(trip_id: "1", latitude: 1.0, longitude: 1.0)
             ] == decoded
    end

    test "trips appear in their order, regardless of VehiclePosition order" do
      trip_updates = [
        TripUpdate.new(trip_id: "1"),
        TripUpdate.new(trip_id: "2"),
        TripUpdate.new(trip_id: "3")
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
               TripUpdate.new(trip_id: "1"),
               VehiclePosition.new(trip_id: "1", latitude: 1.0, longitude: 1.0),
               TripUpdate.new(trip_id: "2"),
               VehiclePosition.new(trip_id: "2", latitude: 1.0, longitude: 1.0),
               TripUpdate.new(trip_id: "3"),
               VehiclePosition.new(trip_id: "3", latitude: 1.0, longitude: 1.0)
             ] == decoded
    end

    test "decoding and re-encoding vehiclepositions.pb is a no-op" do
      decoded = GTFSRealtime.parse(File.read!(fixture_path("vehiclepositions.pb")))
      assert round_trip(decoded) == decoded
    end
  end

  defp round_trip(data) do
    # return the result of decoding the encoded data
    GTFSRealtime.parse(encode(data))
  end
end
