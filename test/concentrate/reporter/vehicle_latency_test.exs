defmodule Concentrate.Reporter.VehicleLatencyTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Reporter.VehicleLatency
  alias Concentrate.VehiclePosition

  describe "log/2" do
    test "logs undefined if there aren't any vehicles with timestamps" do
      state = init()

      expected = [
        latest_vehicle_lateness: :undefined,
        average_vehicle_lateness: :undefined,
        vehicle_count: 0
      ]

      assert {^expected, _} = log([{nil, [], []}], state)

      assert {^expected, _} =
               log([{nil, [VehiclePosition.new(latitude: 1, longitude: 1)], []}], state)
    end

    test "logs the difference with utc_now from the most-up-to-date vehicle" do
      state = init()
      vp = VehiclePosition.new(latitude: 1, longitude: 1)
      now = utc_now()

      group = {
        Concentrate.TripDescriptor.new([]),
        [
          VehiclePosition.update_last_updated(vp, now - 5),
          VehiclePosition.update_last_updated(vp, now - 3),
          VehiclePosition.update_last_updated(vp, now - 10)
        ],
        []
      }

      average_lateness = (5 + 3 + 10) / 3

      expected = [
        latest_vehicle_lateness: 3,
        average_vehicle_lateness: average_lateness,
        vehicle_count: 3
      ]

      assert {^expected, _} = log([group], state)
    end
  end

  def utc_now do
    DateTime.to_unix(DateTime.utc_now())
  end
end
