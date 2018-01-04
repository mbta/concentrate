defmodule Concentrate.Parser.GTFSRealtimeEnhancedTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.TestHelpers
  import Concentrate.Parser.GTFSRealtimeEnhanced
  alias Concentrate.{TripUpdate, StopTimeUpdate, Alert, Alert.InformedEntity}

  describe "parse/1" do
    test "parsing a TripUpdate enhanced JSON file returns only StopTimeUpdate or TripUpdate structs" do
      binary = File.read!(fixture_path("TripUpdates_enhanced.json"))
      parsed = parse(binary, [])
      assert [_ | _] = parsed

      for update <- parsed do
        assert update.__struct__ in [StopTimeUpdate, TripUpdate]
      end
    end

    test "parsing an alerts_enhanced.json file returns only alerts" do
      binary = File.read!(fixture_path("alerts_enhanced.json"))
      parsed = parse(binary, [])
      assert [_ | _] = parsed

      for alert <- parsed do
        assert alert.__struct__ == Alert
      end
    end

    test "alerts decode all entity fields" do
      body = ~s(
        {
          "entity": [
            {
              "id": "id",
              "alert": {
                "effect": "STOP_MOVED",
                "informed_entity": [
                  {
                    "route_type": 2,
                    "route_id": "CR-Worcester",
                    "trip": {
                      "route_id": "CR-Worcester",
                      "trip_id": "CR-Weekday-Fall-17-516"
                    },
                    "stop_id": "Worcester",
                    "activities": [
                      "BOARD",
                      "EXIT",
                      "RIDE"
                    ]
                  }
                ]
              }
            }
          ]
        })
      [alert] = parse(body, [])
      [entity] = Alert.informed_entity(alert)
      assert InformedEntity.route_type(entity) == 2
      assert InformedEntity.route_id(entity) == "CR-Worcester"
      assert InformedEntity.trip_id(entity) == "CR-Weekday-Fall-17-516"
      assert InformedEntity.stop_id(entity) == "Worcester"
      assert InformedEntity.activities(entity) == ~w(BOARD EXIT RIDE)
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
