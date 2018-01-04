defmodule Concentrate.Encoder.TripUpdatesEnhancedTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.TestHelpers
  import Concentrate.Encoder.TripUpdatesEnhanced
  alias Concentrate.Parser.GTFSRealtimeEnhanced
  alias Concentrate.{TripUpdate, StopTimeUpdate}

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

      encoded = Poison.decode!(encode(parsed))
      update = get_in(encoded, ["entity", Access.at(0), "trip_update", "trip"])
      refute "start_time" in Map.keys(update)
    end

    test "stop time updates without a status don't have that key" do
      parsed = [
        TripUpdate.new(trip_id: "trip"),
        StopTimeUpdate.new(trip_id: "trip", stop_id: "5")
      ]

      encoded = Poison.decode!(encode(parsed))

      update =
        get_in(encoded, ["entity", Access.at(0), "trip_update", "stop_time_update", Access.at(0)])

      refute "boarding_status" in Map.keys(update)
    end
  end
end
