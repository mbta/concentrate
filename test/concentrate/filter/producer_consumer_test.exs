defmodule Concentrate.Filter.ProducerConsumerTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Filter.ProducerConsumer
  alias Concentrate.VehiclePosition

  describe "handle_events/3" do
    test "runs the last events through the filter" do
      data = [
        VehiclePosition.new(latitude: 1, longitude: 1),
        expected = VehiclePosition.new(trip_id: "trip", latitude: 2, longitude: 2)
      ]

      events = [[], data]
      filters = [Concentrate.Filter.VehicleWithNoTrip]
      assert {:noreply, [[^expected]], ^filters} = handle_events(events, :from, filters)
    end
  end
end
