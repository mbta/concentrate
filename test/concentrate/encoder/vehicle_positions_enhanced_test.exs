defmodule Concentrate.Encoder.VehiclePositionsEnhancedTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Encoder.VehiclePositionsEnhanced
  import Concentrate.Encoder.GTFSRealtimeHelpers, only: [group: 1]
  alias Concentrate.Parser.GTFSRealtimeEnhanced
  alias Concentrate.{FeedUpdate, TripDescriptor, VehiclePosition}
  alias VehiclePosition.Consist, as: VehiclePositionConsist

  describe "encode/1" do
    test "can take an optional timestamp and partial? flag" do
      data = [
        VehiclePosition.new(trip_id: "partial", id: "v", latitude: 1, longitude: 1)
      ]

      timestamp = System.system_time(:millisecond) / 1_000

      update = round_trip(data, timestamp: timestamp, partial?: true)
      assert FeedUpdate.timestamp(update) == trunc(timestamp)
      assert FeedUpdate.partial?(update)
    end

    test "includes consist/occupancy data if present" do
      data = [
        TripDescriptor.new(trip_id: "one", vehicle_id: "y1"),
        VehiclePosition.new(
          trip_id: "one",
          id: "y1",
          latitude: 1,
          longitude: 1,
          status: :IN_TRANSIT_TO
        ),
        TripDescriptor.new(trip_id: "two", vehicle_id: "y2"),
        VehiclePosition.new(
          trip_id: "two",
          id: "y2",
          latitude: 2,
          longitude: 2,
          status: :IN_TRANSIT_TO,
          occupancy_status: :FULL,
          occupancy_percentage: 101,
          consist: [
            VehiclePositionConsist.new(label: "y2-1"),
            VehiclePositionConsist.new(label: "y2-2")
          ]
        )
      ]

      assert data == FeedUpdate.updates(round_trip(data))
    end

    test "marks vehicles without trips as UNSCHEDULED" do
      data = [
        VehiclePosition.new(trip_id: "unscheduled", id: "u", latitude: 1, longitude: 1)
      ]

      assert [td, _vp] = FeedUpdate.updates(round_trip(data))
      assert TripDescriptor.schedule_relationship(td) == :UNSCHEDULED
    end

    test "does not use a trip if there's no trip ID" do
      data = [
        VehiclePosition.new(id: "y", latitude: 1, longitude: 1)
      ]

      assert [] == FeedUpdate.updates(round_trip(data))
    end

    test "includes non-revenue trips" do
      data = [
        TripDescriptor.new(trip_id: "one", vehicle_id: "y1", revenue: false),
        VehiclePosition.new(
          trip_id: "one",
          id: "y1",
          latitude: 1,
          longitude: 1,
          status: :IN_TRANSIT_TO
        )
      ]

      assert [
               %Concentrate.TripDescriptor{
                 trip_id: "one",
                 vehicle_id: "y1",
                 revenue: false,
                 schedule_relationship: :SCHEDULED
               },
               %Concentrate.VehiclePosition{
                 id: "y1",
                 trip_id: "one",
                 latitude: 1,
                 longitude: 1,
                 status: :IN_TRANSIT_TO
               }
             ] == FeedUpdate.updates(round_trip(data))
    end

    test "includes last_trip field" do
      data = [
        TripDescriptor.new(trip_id: "one", vehicle_id: "y1"),
        VehiclePosition.new(
          trip_id: "one",
          id: "y1",
          latitude: 1,
          longitude: 1,
          status: :IN_TRANSIT_TO
        ),
        TripDescriptor.new(trip_id: "two", vehicle_id: "y2", last_trip: true),
        VehiclePosition.new(
          trip_id: "two",
          id: "y2",
          latitude: 2,
          longitude: 2,
          status: :IN_TRANSIT_TO,
          occupancy_status: :FULL,
          occupancy_percentage: 101,
          consist: [
            VehiclePositionConsist.new(label: "y2-1"),
            VehiclePositionConsist.new(label: "y2-2")
          ]
        )
      ]

      assert data == FeedUpdate.updates(round_trip(data))
    end
  end

  defp round_trip(data, opts \\ []) do
    # return the result of decoding the encoded data
    data
    |> group()
    |> encode_groups(opts)
    |> GTFSRealtimeEnhanced.parse([])
  end
end
