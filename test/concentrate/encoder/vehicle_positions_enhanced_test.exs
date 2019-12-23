defmodule Concentrate.Encoder.VehiclePositionsEnhancedTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Encoder.VehiclePositionsEnhanced
  import Concentrate.Encoder.GTFSRealtimeHelpers, only: [group: 1]
  alias Concentrate.Parser.GTFSRealtimeEnhanced
  alias Concentrate.{TripUpdate, VehiclePosition}
  alias VehiclePosition.Consist, as: VehiclePositionConsist

  describe "encode/1" do
    test "includes consist data if present" do
      data = [
        TripUpdate.new(trip_id: "one"),
        VehiclePosition.new(trip_id: "one", id: "y1", latitude: 1, longitude: 1),
        TripUpdate.new(trip_id: "two"),
        VehiclePosition.new(
          trip_id: "two",
          id: "y2",
          latitude: 2,
          longitude: 2,
          consist: [
            VehiclePositionConsist.new(label: "y2-1"),
            VehiclePositionConsist.new(label: "y2-2")
          ]
        )
      ]

      assert data == round_trip(data)
    end

    test "marks vehicles without trips as UNSCHEDULED" do
      data = [
        VehiclePosition.new(trip_id: "unscheduled", id: "u", latitude: 1, longitude: 1)
      ]

      assert [tu, vp] = round_trip(data)
      assert TripUpdate.schedule_relationship(tu) == :UNSCHEDULED
    end

    test "does not use a trip if there's no trip ID" do
      data = [
        VehiclePosition.new(id: "y", latitude: 1, longitude: 1)
      ]

      assert [] == round_trip(data)
    end
  end

  defp round_trip(data) do
    # return the result of decoding the encoded data
    GTFSRealtimeEnhanced.parse(encode_groups(group(data)), [])
  end
end