defmodule Concentrate.Parser.GTFSRealtimeEnhancedTest do
  @moduledoc false
  use ExUnit.Case
  import ExUnit.CaptureLog
  import Concentrate.TestHelpers
  import Concentrate.Parser.GTFSRealtimeEnhanced

  alias Concentrate.{
    TripDescriptor,
    StopTimeUpdate,
    VehiclePosition,
    Alert,
    Alert.InformedEntity,
    Parser.Helpers,
    Parser.Helpers.Options
  }

  describe "parse/1" do
    test "parsing a TripDescriptor enhanced JSON file returns only StopTimeUpdate or TripDescriptor structs" do
      binary = File.read!(fixture_path("TripUpdates_enhanced.json"))
      parsed = parse(binary, [])
      assert [_ | _] = parsed

      for update <- parsed do
        assert update.__struct__ in [StopTimeUpdate, TripDescriptor]
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

    test "parsing an enhanced VehiclePositions JSON file returns only VehiclePosition or TripDescriptor structs" do
      binary = File.read!(fixture_path("VehiclePositions_enhanced.json"))
      parsed = parse(binary, [])
      assert [_ | _] = parsed

      for update <- parsed do
        assert update.__struct__ in [VehiclePosition, TripDescriptor]
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
                      "trip_id": "CR-Weekday-Fall-17-516",
                      "direction_id": 1
                    },
                    "stop_id": "Worcester",
                    "activities": [
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
      assert InformedEntity.direction_id(entity) == 1
      assert InformedEntity.trip_id(entity) == "CR-Weekday-Fall-17-516"
      assert InformedEntity.stop_id(entity) == "Worcester"
      assert InformedEntity.activities(entity) == ~w(EXIT RIDE)
    end

    @tag :capture_log
    test "alerts converts unknown effects to UNKNOWN_EFFECT" do
      body = ~s(
        {
          "entity": [
            {
              "id": "id",
              "alert": {
                "effect": "what is this",
                "informed_entity": []
              }
            }
          ]
        })
      [alert] = parse(body, [])
      assert Alert.effect(alert) == :UNKNOWN_EFFECT
    end

    test "alerts can decoded the old-format feed" do
      # top-level "alerts" key
      # id and alert data in same object
      # direction ID in the entity directly
      body = ~s(
        {
          "alerts": [
            {
              "id": "id",
              "effect": "STOP_MOVED",
              "informed_entity": [
                {
                  "route_type": 2,
                  "route_id": "CR-Worcester",
                  "direction_id": 1,
                  "stop_id": "Worcester",
                  "activities": [
                    "BOARD",
                    "EXIT",
                    "RIDE"
                  ]
                }
              ]
            }
          ]
        })
      [alert] = parse(body, [])
      assert Alert.id(alert) == "id"
      [entity] = Alert.informed_entity(alert)
      assert InformedEntity.route_type(entity) == 2
      assert InformedEntity.route_id(entity) == "CR-Worcester"
      assert InformedEntity.direction_id(entity) == 1
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

      [_td, stop_update] = decode_trip_update(update, %Options{})
      assert StopTimeUpdate.status(stop_update) == "ALL_ABOARD"
    end

    test "can handle platform id information" do
      update = %{
        "trip" => %{},
        "stop_time_update" => [
          %{
            "platform_id" => "platform"
          }
        ]
      }

      [_td, stop_update] = decode_trip_update(update, %Options{})
      assert StopTimeUpdate.platform_id(stop_update) == "platform"
    end

    test "treats a missing schedule relationship as SCHEDULED" do
      update = %{
        "trip" => %{},
        "stop_time_update" => [
          %{}
        ]
      }

      [td, stu] = decode_trip_update(update, %Options{})
      assert TripDescriptor.schedule_relationship(td) == :SCHEDULED
      assert StopTimeUpdate.schedule_relationship(stu) == :SCHEDULED
    end

    test "only includes trip/stop update if it's under max_time" do
      update = %{
        "trip" => %{},
        "stop_time_update" => [
          %{
            "departure" => %{"time" => 2}
          }
        ]
      }

      assert [] = decode_trip_update(update, %Options{max_time: 1})
      assert [_, _] = decode_trip_update(update, %Options{max_time: 2})
    end

    test "keeps the whole trip even if later updates are later than the time" do
      update = %{
        "trip" => %{},
        "stop_time_update" => [
          %{
            "arrival" => %{"time" => 1}
          },
          %{
            "departure" => %{"time" => 2}
          }
        ]
      }

      assert [_, _, _] = decode_trip_update(update, %Options{max_time: 1})
    end

    test "drops the TripDescriptor if the route is ignored" do
      update = %{
        "trip" => %{"route_id" => "route"},
        "stop_time_update" => []
      }

      assert [_] = decode_trip_update(update, Helpers.parse_options([]))
      assert [_] = decode_trip_update(update, Helpers.parse_options(routes: ["route"]))
      assert [] = decode_trip_update(update, Helpers.parse_options(excluded_routes: ["route"]))
    end

    test "can include a route_pattern_id in the trip descriptor" do
      map = %{
        "trip" => %{
          "trip_id" => "trip",
          "route_id" => "route",
          "route_pattern_id" => "pattern"
        },
        "stop_time_update" => []
      }

      [td] = decode_trip_update(map, Helpers.parse_options([]))
      assert TripDescriptor.route_pattern_id(td) == "pattern"
    end

    test "includes timestamp if available" do
      map = %{
        "trip" => %{
          "trip_id" => "trip",
          "route_id" => "route"
        },
        "timestamp" => 1_534_340_406,
        "stop_time_update" => []
      }

      [td] = decode_trip_update(map, Helpers.parse_options([]))
      assert TripDescriptor.timestamp(td) == 1_534_340_406
    end

    test "includes vehicle_id if available" do
      map = %{
        "trip" => %{
          "trip_id" => "trip",
          "route_id" => "route"
        },
        "vehicle" => %{
          "id" => "vehicle_id"
        },
        "stop_time_update" => []
      }

      [td] = decode_trip_update(map, Helpers.parse_options([]))
      assert TripDescriptor.vehicle_id(td) == "vehicle_id"
    end
  end

  describe "decode_vehicle/3" do
    test "returns nothing if there's an empty map" do
      assert decode_vehicle(%{}, Helpers.parse_options([]), nil) == []
    end

    test "drops the VehiclePosition if the route is ignored" do
      map = %{
        "trip" => %{"route_id" => "route"},
        "position" => %{
          "latitude" => 1.0,
          "longitude" => 1.0
        }
      }

      assert [_, _] = decode_vehicle(map, Helpers.parse_options([]), nil)
      assert [_, _] = decode_vehicle(map, Helpers.parse_options(routes: ["route"]), nil)
      assert [] = decode_vehicle(map, Helpers.parse_options(excluded_routes: ["route"]), nil)
    end

    test "decodes a VehiclePosition JSON map" do
      map = %{
        "congestion_level" => nil,
        "current_status" => "STOPPED_AT",
        "current_stop_sequence" => 670,
        "occupancy_status" => "MANY_SEATS_AVAILABLE",
        "occupancy_percentage" => 50,
        "position" => %{
          "bearing" => 135,
          "latitude" => 42.32951,
          "longitude" => -71.11109,
          "odometer" => nil,
          "speed" => nil
        },
        "stop_id" => "70257",
        "timestamp" => 1_534_340_406,
        "trip" => %{
          "direction_id" => 0,
          "route_id" => "Green-E",
          "schedule_relationship" => "SCHEDULED",
          "start_date" => "20180815",
          "start_time" => nil,
          "trip_id" => "37165437-X"
        },
        "vehicle" => %{
          "id" => "G-10098",
          "label" => "3823-3605",
          "license_plate" => nil
        }
      }

      assert [td, vp] = decode_vehicle(map, Helpers.parse_options([]), nil)

      assert td ==
               TripDescriptor.new(
                 trip_id: "37165437-X",
                 route_id: "Green-E",
                 direction_id: 0,
                 start_date: {2018, 8, 15},
                 schedule_relationship: :SCHEDULED,
                 timestamp: 1_534_340_406,
                 vehicle_id: "G-10098"
               )

      assert vp ==
               VehiclePosition.new(
                 id: "G-10098",
                 label: "3823-3605",
                 latitude: 42.32951,
                 longitude: -71.11109,
                 bearing: 135,
                 stop_id: "70257",
                 trip_id: "37165437-X",
                 stop_sequence: 670,
                 status: :STOPPED_AT,
                 last_updated: 1_534_340_406,
                 occupancy_status: :MANY_SEATS_AVAILABLE,
                 occupancy_percentage: 50
               )
    end

    test "can include a consist in the VehiclePositions struct" do
      map = %{
        "congestion_level" => nil,
        "current_status" => "STOPPED_AT",
        "current_stop_sequence" => 670,
        "occupancy_status" => nil,
        "position" => %{
          "bearing" => 135,
          "latitude" => 42.32951,
          "longitude" => -71.11109,
          "odometer" => nil,
          "speed" => nil
        },
        "stop_id" => "70257",
        "timestamp" => 1_534_340_406,
        "trip" => %{},
        "vehicle" => %{
          "id" => "G-10098",
          "label" => "3823-3605",
          "license_plate" => nil,
          "consist" => [
            %{"label" => "3823"},
            %{"label" => "3605"}
          ]
        }
      }

      assert [_td, vp] = decode_vehicle(map, Helpers.parse_options([]), nil)

      assert VehiclePosition.consist(vp) == [
               VehiclePosition.Consist.new(label: "3823"),
               VehiclePosition.Consist.new(label: "3605")
             ]
    end

    test "logs when vehicle timestamp is later than feed timestamp" do
      map = %{
        "congestion_level" => nil,
        "current_status" => "STOPPED_AT",
        "current_stop_sequence" => 670,
        "occupancy_status" => nil,
        "position" => %{
          "bearing" => 135,
          "latitude" => 42.32951,
          "longitude" => -71.11109,
          "odometer" => nil,
          "speed" => nil
        },
        "stop_id" => "70257",
        "timestamp" => 1_534_340_406,
        "trip" => %{},
        "vehicle" => %{
          "id" => "G-10098",
          "label" => "3823-3605",
          "license_plate" => nil,
          "consist" => [
            %{"label" => "3823"},
            %{"label" => "3605"}
          ]
        }
      }

      log =
        capture_log([level: :warn], fn ->
          decode_vehicle(map, Helpers.parse_options(feed_url: "test_url"), 1_534_340_306)
        end)

      assert log =~ "vehicle timestamp after feed timestamp"
    end
  end
end
