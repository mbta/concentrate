defmodule Concentrate.Encoder.TripUpdatesEnhancedTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.TestHelpers
  import Concentrate.Encoder.TripUpdatesEnhanced
  import Concentrate.Encoder.GTFSRealtimeHelpers, only: [group: 1]
  alias Concentrate.Parser.GTFSRealtimeEnhanced
  alias Concentrate.{StopTimeUpdate, TripDescriptor, VehiclePosition}

  describe "encode_groups/1" do
    test "decoding and re-encoding TripUpdates_enhanced.json is a no-op" do
      decoded =
        GTFSRealtimeEnhanced.parse(File.read!(fixture_path("TripUpdates_enhanced.json")), [])

      round_tripped = GTFSRealtimeEnhanced.parse(encode_groups(group(decoded)), [])
      assert Enum.sort(round_tripped) == Enum.sort(decoded)
    end

    test "trip updates without a start_time don't have that key" do
      parsed = [
        TripDescriptor.new(trip_id: "trip"),
        StopTimeUpdate.new(trip_id: "trip", stop_id: "5")
      ]

      encoded = Jason.decode!(encode_groups(group(parsed)))
      update = get_in(encoded, ["entity", Access.at(0), "trip_update", "trip"])
      refute "start_time" in Map.keys(update)
    end

    test "stop time updates without a status don't have that key" do
      parsed = [
        TripDescriptor.new(trip_id: "trip"),
        StopTimeUpdate.new(trip_id: "trip", stop_id: "5")
      ]

      encoded = Jason.decode!(encode_groups(group(parsed)))

      update =
        get_in(encoded, ["entity", Access.at(0), "trip_update", "stop_time_update", Access.at(0)])

      refute "boarding_status" in Map.keys(update)
    end

    test "trips with only vehicles aren't encoded" do
      initial = [
        TripDescriptor.new(trip_id: "1"),
        VehiclePosition.new(trip_id: "1", latitude: 1, longitude: 1)
      ]

      decoded = Jason.decode!(encode_groups(group(initial)))
      assert decoded["entity"] == []
    end

    test "trips with a non-SCHEDULED relationship can appear alone" do
      initial = [
        TripDescriptor.new(trip_id: "1", schedule_relationship: :CANCELED)
      ]

      decoded = Jason.decode!(encode_groups(group(initial)))
      trip_update = get_in(decoded, ["entity", Access.at(0), "trip_update"])
      assert trip_update
      assert trip_update["trip"]["schedule_relationship"] == "CANCELED"
      refute "stop_time_update" in Map.keys(trip_update)
    end

    test "trips/updates with schedule_relationship SCHEDULED don't have that field" do
      parsed = [
        TripDescriptor.new(trip_id: "trip", schedule_relationship: :SCHEDULED),
        StopTimeUpdate.new(trip_id: "trip", stop_id: "stop", schedule_relationship: :SCHEDULED)
      ]

      encoded = Jason.decode!(encode_groups(group(parsed)))

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

    test "trips with route_pattern_id present have that field" do
      parsed = [
        TripDescriptor.new(trip_id: "trip", route_pattern_id: "pattern"),
        StopTimeUpdate.new(trip_id: "trip", stop_id: "stop")
      ]

      encoded = Jason.decode!(encode_groups(group(parsed)))

      assert %{
               "entity" => [
                 %{
                   "trip_update" => %{
                     "trip" => %{
                       "route_pattern_id" => "pattern",
                       "last_trip" => false
                     }
                   }
                 }
               ]
             } = encoded
    end

    test "trips updates with timestamp present have that field" do
      parsed = [
        TripDescriptor.new(trip_id: "trip", timestamp: 1_534_340_406),
        StopTimeUpdate.new(trip_id: "trip", stop_id: "stop")
      ]

      encoded = Jason.decode!(encode_groups(group(parsed)))

      assert %{
               "entity" => [
                 %{
                   "trip_update" => %{
                     "timestamp" => 1_534_340_406,
                     "trip" => %{}
                   }
                 }
               ]
             } = encoded
    end

    test "Non-revenue trips are included" do
      parsed = [
        TripDescriptor.new(
          trip_id: "NONREV-trip",
          route_id: "route",
          direction_id: 0,
          revenue: false
        ),
        StopTimeUpdate.new(
          trip_id: "NONREV-trip",
          stop_id: "stop",
          schedule_relationship: :SKIPPED
        )
      ]

      encoded = Jason.decode!(encode_groups(group(parsed)))

      assert %{
               "entity" => [
                 %{
                   "id" => "NONREV-trip",
                   "trip_update" => %{
                     "trip" => %{
                       "direction_id" => 0,
                       "revenue" => false,
                       "route_id" => "route",
                       "trip_id" => "NONREV-trip",
                       "last_trip" => false
                     }
                   }
                 }
               ]
             } = encoded
    end

    test "last_trip field is included" do
      parsed = [
        TripDescriptor.new(
          trip_id: "trip",
          route_id: "route",
          direction_id: 0,
          last_trip: true
        ),
        StopTimeUpdate.new(
          trip_id: "trip",
          stop_id: "stop"
        )
      ]

      encoded = Jason.decode!(encode_groups(group(parsed)))

      assert %{
               "entity" => [
                 %{
                   "id" => "trip",
                   "trip_update" => %{
                     "trip" => %{
                       "direction_id" => 0,
                       "revenue" => true,
                       "route_id" => "route",
                       "trip_id" => "trip",
                       "last_trip" => true
                     }
                   }
                 }
               ]
             } = encoded
    end

    test "moves update_type from trip to trip_update" do
      parsed = [
        TripDescriptor.new(trip_id: "trip", update_type: "mid_trip"),
        StopTimeUpdate.new(trip_id: "trip", stop_id: "stop")
      ]

      encoded = Jason.decode!(encode_groups(group(parsed)))

      assert %{
               "entity" => [
                 %{
                   "trip_update" => %{
                     "update_type" => "mid_trip",
                     "trip" => %{}
                   }
                 }
               ]
             } = encoded

      trip = get_in(encoded, ["entity", Access.at(0), "trip_update", "trip"])
      refute trip["update_type"]
    end

    test "includes passthrough_time" do
      parsed = [
        TripDescriptor.new(
          trip_id: "trip",
          route_id: "route",
          direction_id: 0,
          schedule_relationship: :ADDED,
          revenue: true
        ),
        StopTimeUpdate.new(
          trip_id: "trip",
          stop_id: "stop_1",
          schedule_relationship: :SKIPPED,
          departure_time: 100,
          passthrough_time: 100
        ),
        StopTimeUpdate.new(
          trip_id: "trip",
          stop_id: "stop_2",
          schedule_relationship: :SKIPPED,
          arrival_time: 200,
          departure_time: 250,
          passthrough_time: 200
        ),
        StopTimeUpdate.new(
          trip_id: "trip",
          stop_id: "stop_3",
          arrival_time: 300,
          departure_time: 400
        )
      ]

      encoded = Jason.decode!(encode_groups(group(parsed)))

      assert %{
               "entity" => [
                 %{
                   "id" => "trip",
                   "trip_update" => %{
                     "trip" => %{
                       "direction_id" => 0,
                       "revenue" => true,
                       "route_id" => "route",
                       "trip_id" => "trip",
                       "last_trip" => false
                     },
                     "stop_time_update" => [
                       %{
                         "arrival" => %{"time" => 300},
                         "departure" => %{"time" => 400},
                         "stop_id" => "stop_3"
                       } = stu_3,
                       %{
                         "passthrough_time" => 200,
                         "schedule_relationship" => "SKIPPED",
                         "stop_id" => "stop_2"
                       } = stu_2,
                       %{
                         "passthrough_time" => 100,
                         "schedule_relationship" => "SKIPPED",
                         "stop_id" => "stop_1"
                       } = stu_1
                     ]
                   }
                 }
               ]
             } = encoded

      refute Map.get(stu_1, "arrival")
      refute Map.get(stu_1, "departure")
      refute Map.get(stu_2, "arrival")
      refute Map.get(stu_2, "departure")
      refute Map.get(stu_3, "passthrough_time")
    end
  end
end
