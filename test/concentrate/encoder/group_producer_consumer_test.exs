defmodule Concentrate.Encoder.GroupProducerConsumerTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Encoder.GroupProducerConsumer
  import Concentrate.Encoder.GTFSRealtimeHelpers
  alias Concentrate.{TripUpdate, VehiclePosition, StopTimeUpdate}

  describe "handle_events/3" do
    test "groups the parsed data" do
      {_, state, _} = init([])

      data = [TripUpdate.new(trip_id: "trip"), StopTimeUpdate.new(trip_id: "trip")]
      expected = group(data)
      {:noreply, events, _state} = handle_events([[], data], :from, state)

      assert events == [expected]
    end

    test "can filter the grouped data" do
      defmodule Filter do
        @moduledoc false
        @behaviour Concentrate.GroupFilter
        def filter({trip, _vehicles, stop_updates}) do
          {trip, [], stop_updates}
        end
      end

      {_, state, _} = init(filters: [__MODULE__.Filter])

      data = [
        trip = TripUpdate.new(trip_id: "trip"),
        VehiclePosition.new(trip_id: "trip", latitude: 1, longitude: 1),
        stu = StopTimeUpdate.new(trip_id: "trip")
      ]

      expected = [{trip, [], [stu]}]
      {:noreply, events, _state} = handle_events([data], :from, state)
      assert events == [expected]
    end

    test "removes empty results post-filter" do
      filter = fn {_, _, _} -> {nil, [], []} end
      {_, state, _} = init(filters: [filter])

      data = [
        TripUpdate.new(trip_id: "trip"),
        StopTimeUpdate.new(trip_id: "trip")
      ]

      expected = []
      {:noreply, events, _state} = handle_events([data], :from, state)
      assert events == [expected]
    end
  end
end
