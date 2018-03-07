defmodule Concentrate.Encoder.GroupProducerConsumerTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Encoder.GroupProducerConsumer
  import Concentrate.Encoder.GTFSRealtimeHelpers
  alias Concentrate.{TripUpdate, StopTimeUpdate}

  describe "handle_events/3" do
    test "groups the parsed data" do
      {_, state, _} = init([])

      data = [TripUpdate.new(trip_id: "trip"), StopTimeUpdate.new(trip_id: "trip")]
      expected = group(data)
      {:noreply, events, _state} = handle_events([[], data], :from, state)

      assert events == [expected]
    end
  end
end
