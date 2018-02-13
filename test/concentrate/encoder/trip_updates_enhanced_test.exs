defmodule Concentrate.Encoder.TripUpdatesEnhancedTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.TestHelpers
  import Concentrate.Encoder.TripUpdatesEnhanced
  alias Concentrate.Parser.GTFSRealtimeEnhanced
  alias Concentrate.{TripUpdate, VehiclePosition, StopTimeUpdate}

  describe "encode/1" do
    test "decoding and re-encoding TripUpdates_enhanced.json is a no-op" do
      decoded =
        GTFSRealtimeEnhanced.parse(File.read!(fixture_path("TripUpdates_enhanced.json")), [])

      round_tripped = GTFSRealtimeEnhanced.parse(encode(decoded), [])
      assert round_tripped == decoded
    end

    test "trip updates without a start_time don't have that key" do
      parsed = [
        TripUpdate.new(trip_id: "trip"),
        StopTimeUpdate.new(trip_id: "trip", stop_id: "5")
      ]

      encoded = Jason.decode!(encode(parsed))
      update = get_in(encoded, ["entity", Access.at(0), "trip_update", "trip"])
      refute "start_time" in Map.keys(update)
    end

    test "stop time updates without a status don't have that key" do
      parsed = [
        TripUpdate.new(trip_id: "trip"),
        StopTimeUpdate.new(trip_id: "trip", stop_id: "5")
      ]

      encoded = Jason.decode!(encode(parsed))

      update =
        get_in(encoded, ["entity", Access.at(0), "trip_update", "stop_time_update", Access.at(0)])

      refute "boarding_status" in Map.keys(update)
    end

    test "trips with only vehicles aren't encoded" do
      initial = [
        TripUpdate.new(trip_id: "1"),
        VehiclePosition.new(trip_id: "1", latitude: 1, longitude: 1)
      ]

      decoded = Jason.decode!(encode(initial))
      assert decoded["entity"] == []
    end

    test "trips/updates with schedule_relationship SCHEDULED don't have that field" do
      parsed = [
        TripUpdate.new(trip_id: "trip", schedule_relationship: :SCHEDULED),
        StopTimeUpdate.new(trip_id: "trip", stop_id: "stop", schedule_relationship: :SCHEDULED)
      ]

      encoded = Jason.decode!(encode(parsed))

      %{
        "entity" => [
          %{
            "trip_update" => %{
              "trip" => trip,
              "stop_time_update" => [update]
            }
          }
        ]
      } = encoded

      refute "schedule_relationship" in Map.keys(trip)
      refute "schedule_relationship" in Map.keys(update)
    end
  end
end
