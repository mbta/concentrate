defmodule Concentrate.Encoder.ProducerConsumerTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Encoder.ProducerConsumer
  import Concentrate.Encoder.GTFSRealtimeHelpers
  alias Concentrate.{TripDescriptor, StopTimeUpdate}
  alias Concentrate.Encoder.{TripUpdates, VehiclePositions}

  describe "handle_events/3" do
    test "encodes each file and outputs it" do
      {_, state, _} =
        init(files: [{"TripUpdates.pb", TripUpdates}, {"VehiclePositions.pb", VehiclePositions}])

      data =
        group([
          TripDescriptor.new(trip_id: "trip"),
          StopTimeUpdate.new(trip_id: "trip", departure_time: 1)
        ])

      {:noreply, events, _state, :hibernate} = handle_events([[], data], :from, state)

      assert [{"TripUpdates.pb", trip_update}, {"VehiclePositions.pb", vehicle_positions}] =
               events

      # trip_update has data and vehicle positions shouldn't
      assert bit_size(trip_update) > bit_size(vehicle_positions)
    end
  end
end
