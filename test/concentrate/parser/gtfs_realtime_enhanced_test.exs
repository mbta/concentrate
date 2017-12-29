defmodule Concentrate.Parser.GTFSRealtimeEnhancedTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.TestHelpers
  import Concentrate.Parser.GTFSRealtimeEnhanced
  alias Concentrate.{TripUpdate, StopTimeUpdate, Alert}

  describe "parse/1" do
    test "parsing a TripUpdate enhanced JSON file returns only StopTimeUpdate or TripUpdate structs" do
      binary = File.read!(fixture_path("TripUpdates_enhanced.json"))
      parsed = parse(binary)
      assert [_ | _] = parsed

      for update <- parsed do
        assert update.__struct__ in [StopTimeUpdate, TripUpdate]
      end
    end

    test "parsing an alerts_enhanced.json file returns only alerts" do
      binary = File.read!(fixture_path("alerts_enhanced.json"))
      parsed = parse(binary)
      assert [_ | _] = parsed

      for alert <- parsed do
        assert alert.__struct__ == Alert
      end
    end
  end

  describe "decode_trip_update/1" do
    test "can handle boarding status information" do
      update = %{
        "trip" => %{},
        "stop_time_update" => [
          %{
            "boarding_status" => "ALL_ABOARD"
          }
        ]
      }

      [_tu, stop_update] = decode_trip_update(update)
      assert StopTimeUpdate.status(stop_update) == :ALL_ABOARD
    end
  end
end
