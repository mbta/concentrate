defmodule Concentrate.Encoder.TripUpdatesTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.TestHelpers
  import Concentrate.Encoder.TripUpdates
  alias Concentrate.{TripUpdate, VehiclePosition, StopTimeUpdate}
  alias Concentrate.Parser.GTFSRealtime

  describe "encode/1" do
    test "order of trip updates doesn't matter" do
      initial = [
        TripUpdate.new(trip_id: "1"),
        TripUpdate.new(trip_id: "2"),
        StopTimeUpdate.new(trip_id: "1")
      ]

      decoded = GTFSRealtime.parse(encode(initial), [])
      assert [TripUpdate.new(trip_id: "1"), StopTimeUpdate.new(trip_id: "1")] == decoded
    end

    test "trips appear in their order, regardless of StopTimeUpdate order" do
      trip_updates = [
        TripUpdate.new(trip_id: "1"),
        TripUpdate.new(trip_id: "2"),
        TripUpdate.new(trip_id: "3")
      ]

      stop_time_updates =
        Enum.shuffle([
          StopTimeUpdate.new(trip_id: "1"),
          StopTimeUpdate.new(trip_id: "2"),
          StopTimeUpdate.new(trip_id: "3")
        ])

      initial = trip_updates ++ stop_time_updates
      decoded = GTFSRealtime.parse(encode(initial), [])

      assert [
               TripUpdate.new(trip_id: "1"),
               StopTimeUpdate.new(trip_id: "1"),
               TripUpdate.new(trip_id: "2"),
               StopTimeUpdate.new(trip_id: "2"),
               TripUpdate.new(trip_id: "3"),
               StopTimeUpdate.new(trip_id: "3")
             ] == decoded
    end

    test "trips with only vehicles aren't encoded" do
      initial = [
        TripUpdate.new(trip_id: "1"),
        VehiclePosition.new(trip_id: "1", latitude: 1, longitude: 1)
      ]

      decoded = GTFSRealtime.parse(encode(initial), [])
      assert decoded == []
    end

    test "trips include part of vehicles" do
      initial = [
        TripUpdate.new(trip_id: "1"),
        StopTimeUpdate.new(trip_id: "1"),
        VehiclePosition.new(
          trip_id: "1",
          latitude: 1,
          longitude: 1,
          id: "id",
          label: "label",
          license_plate: "plate"
        )
      ]

      decoded = :gtfs_realtime_proto.decode_msg(encode(initial), :FeedMessage, [])

      assert %{
               entity: [
                 %{trip_update: %{vehicle: %{id: "id", label: "label", license_plate: "plate"}}}
               ]
             } = decoded
    end

    test "decoding and re-encoding tripupdates.pb is a no-op" do
      decoded = GTFSRealtime.parse(File.read!(fixture_path("tripupdates.pb")), [])
      round_tripped = GTFSRealtime.parse(encode(decoded), [])
      assert round_tripped == decoded
    end

    test "interspersing VehiclePositions doesn't affect the output (with non-matching trips)" do
      decoded = GTFSRealtime.parse(File.read!(fixture_path("tripupdates.pb")), [])

      interspersed =
        Enum.intersperse(
          decoded,
          VehiclePosition.new(trip_id: "non_matching", latitude: 1, longitude: 1)
        )

      round_tripped = GTFSRealtime.parse(encode(interspersed), [])
      assert round_tripped == decoded
    end
  end
end
