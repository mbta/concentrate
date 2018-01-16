defmodule Concentrate.Reporter.VehicleLatencyTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Reporter.VehicleLatency
  alias Concentrate.VehiclePosition

  describe "log/2" do
    test "logs undefined if there aren't any vehicles with timestamps" do
      state = init()
      assert {[latest_vehicle_lateness: :undefined], _} = log([], state)

      assert {[latest_vehicle_lateness: :undefined], _} =
               log([VehiclePosition.new(latitude: 1, longitude: 1)], state)
    end

    test "logs the difference with utc_now from the most-up-to-date vehicle" do
      state = init()
      vp = VehiclePosition.new(latitude: 1, longitude: 1)
      now = utc_now()

      vehicles = [
        VehiclePosition.update_last_updated(vp, now - 5),
        VehiclePosition.update_last_updated(vp, now - 3),
        VehiclePosition.update_last_updated(vp, 0),
        Concentrate.TripUpdate.new([])
      ]

      assert {[latest_vehicle_lateness: 3], _} = log(vehicles, state)
    end
  end

  def utc_now do
    DateTime.to_unix(DateTime.utc_now())
  end
end
