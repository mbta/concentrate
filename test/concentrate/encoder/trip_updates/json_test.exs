defmodule Concentrate.Encoder.TripUpdates.JSONTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Encoder.TripUpdates.JSON
  alias Concentrate.{TripUpdate, StopTimeUpdate}

  describe "encode/1" do
    test "same output as EncoderTripUpdates.encode/1 but in JSON" do
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
      %{"header" =>  _, "entity" => entity} =
        initial
        |> encode()
        |> Jason.decode!

      assert length(entity) == 3
      assert List.first(entity) ==
        %{"id" => "1",
          "trip_update" => %{
            "stop_time_update" => [%{"schedule_relationship" => "SCHEDULED"}],
            "trip" => %{
              "schedule_relationship" => "SCHEDULED",
              "trip_id" => "1"
            }
          }
        }
    end
  end
end
