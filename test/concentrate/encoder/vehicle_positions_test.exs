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

      assert [%TripUpdate{}, %VehiclePosition{}] = GTFSRealtime.parse(encode(data))
    end
  end

  describe "encode/1 round trip" do
    test "decoding and re-encoding vehiclepositions.pb is a no-op" do
      decoded = GTFSRealtime.parse(File.read!(fixture_path("vehiclepositions.pb")))
      round_tripped = GTFSRealtime.parse(encode(decoded))
      assert round_tripped == decoded
    end
  end
end
