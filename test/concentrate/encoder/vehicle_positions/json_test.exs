defmodule Concentrate.Encoder.VehiclePositions.JSONTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Encoder.VehiclePositions.JSON
  alias Concentrate.{TripUpdate, VehiclePosition}

  describe "encode/1" do
    test "same output as Encoder.VehiclePositions.encode/1 but in JSON" do
      initial = [
        TripUpdate.new(trip_id: "1"),
        TripUpdate.new(trip_id: "2"),
        VehiclePosition.new(trip_id: "1", latitude: 1.0, longitude: 1.0),
        VehiclePosition.new(trip_id: "2", latitude: 2.0, longitude: 2.0)
      ]

      %{"header" =>  _, "entity" => entity} =
        initial
        |> encode()
        |> Jason.decode!

      assert length(entity) == 2
      assert List.first(entity) ==
        %{
          "id" => "1",
          "vehicle" => %{
            "current_status" => "IN_TRANSIT_TO",
            "position" => %{"latitude" => 1.0, "longitude" => 1.0},
            "trip" => %{"schedule_relationship" => "SCHEDULED", "trip_id" => "1"},
            "vehicle" => %{}
          }
        }

    end
  end
end
