defmodule Concentrate.Encoder.TripUpdates.JSONTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Encoder.TripUpdates.JSON
  import Concentrate.Encoder.GTFSRealtimeHelpers, only: [group: 1]
  alias Concentrate.{TripDescriptor, StopTimeUpdate}

  describe "encode_groups/1" do
    test "same output as EncoderTripUpdates.encode_groups/1 but in JSON" do
      trip_updates = [
        TripDescriptor.new(trip_id: "1", schedule_relationship: :ADDED, timestamp: 1_534_340_406),
        TripDescriptor.new(trip_id: "2"),
        TripDescriptor.new(trip_id: "3")
      ]

      stop_time_updates =
        Enum.shuffle([
          StopTimeUpdate.new(trip_id: "1", schedule_relationship: :SKIPPED),
          StopTimeUpdate.new(trip_id: "2", departure_time: 2),
          StopTimeUpdate.new(trip_id: "3", arrival_time: 3)
        ])

      initial = trip_updates ++ stop_time_updates

      %{"header" => _, "entity" => entity} =
        initial
        |> group()
        |> encode_groups()
        |> Jason.decode!()

      assert length(entity) == 3

      assert List.first(entity) ==
               %{
                 "id" => "1",
                 "trip_update" => %{
                   "timestamp" => 1_534_340_406,
                   "stop_time_update" => [%{"schedule_relationship" => "SKIPPED"}],
                   "trip" => %{
                     "schedule_relationship" => "ADDED",
                     "trip_id" => "1"
                   }
                 }
               }
    end

    test "trips/updates with schedule_relationship SCHEDULED don't have that field" do
      parsed = [
        TripDescriptor.new(trip_id: "trip", schedule_relationship: :SCHEDULED),
        StopTimeUpdate.new(
          trip_id: "trip",
          stop_id: "stop",
          schedule_relationship: :SCHEDULED,
          arrival_time: 1
        )
      ]

      encoded = parsed |> group() |> encode_groups() |> Jason.decode!()

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
