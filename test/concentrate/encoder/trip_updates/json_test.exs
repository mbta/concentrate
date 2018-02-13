defmodule Concentrate.Encoder.TripUpdates.JSONTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Encoder.TripUpdates.JSON
  alias Concentrate.{TripUpdate, StopTimeUpdate}

  describe "encode/1" do
    test "same output as EncoderTripUpdates.encode/1 but in JSON" do
      trip_updates = [
        TripUpdate.new(trip_id: "1", schedule_relationship: :ADDED),
        TripUpdate.new(trip_id: "2"),
        TripUpdate.new(trip_id: "3")
      ]

      stop_time_updates =
        Enum.shuffle([
          StopTimeUpdate.new(trip_id: "1", schedule_relationship: :SKIPPED),
          StopTimeUpdate.new(trip_id: "2"),
          StopTimeUpdate.new(trip_id: "3")
        ])

      initial = trip_updates ++ stop_time_updates

      %{"header" => _, "entity" => entity} =
        initial
        |> encode()
        |> Jason.decode!()

      assert length(entity) == 3

      assert List.first(entity) ==
               %{
                 "id" => "1",
                 "trip_update" => %{
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
