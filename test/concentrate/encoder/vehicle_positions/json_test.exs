defmodule Concentrate.Encoder.VehiclePositions.JSONTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Encoder.VehiclePositions.JSON
  import Concentrate.Encoder.GTFSRealtimeHelpers, only: [group: 1]
  alias Concentrate.{TripDescriptor, VehiclePosition}

  describe "encode_groups/1" do
    test "same output as Encoder.VehiclePositions.encode_groups/1 but in JSON" do
      initial = [
        TripDescriptor.new(trip_id: "1"),
        TripDescriptor.new(trip_id: "2"),
        VehiclePosition.new(trip_id: "1", latitude: 1.0, longitude: 1.0),
        VehiclePosition.new(trip_id: "2", latitude: 2.0, longitude: 2.0)
      ]

      %{"header" => _, "entity" => entity} =
        initial
        |> group()
        |> encode_groups()
        |> Jason.decode!()

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
