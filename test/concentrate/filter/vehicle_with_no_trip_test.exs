defmodule Concentrate.Filter.VehicleWithNoTripTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Filter.VehicleWithNoTrip
  alias Concentrate.VehiclePosition

  @state init()

  describe "filter/2" do
    test "a vehicle position with a trip is kept" do
      vp = VehiclePosition.new(trip_id: "trip", latitude: 1, longitude: 1)
      assert {:cont, ^vp, _} = filter(vp, @state)
    end

    test "a vehicle position without a trip is removed" do
      vp = VehiclePosition.new(latitude: 1, longitude: 1)
      assert {:skip, _} = filter(vp, @state)
    end

    test "other values are returned as-is" do
      assert {:cont, :value, _} = filter(:value, @state)
    end
  end
end
