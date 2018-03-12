defmodule Concentrate.Filter.RoundSpeedToIntegerTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Filter.RoundSpeedToInteger
  alias Concentrate.VehiclePosition

  describe "filter/1" do
    test "a vehicle position with no speed or bearing is unchanged" do
      vp = VehiclePosition.new(latitude: 1, longitude: 1)
      assert {:cont, ^vp} = filter(vp)
    end

    test "a vehicle position with a float speed or bearing is truncated" do
      vp = VehiclePosition.new(speed: 1.5, bearing: -123.45, latitude: 1, longitude: 1)
      {:cont, new_vp} = filter(vp)
      assert VehiclePosition.speed(new_vp) == 1
      assert VehiclePosition.bearing(new_vp) == -123
    end

    test "small speeds (but not bearings) are converted to nil" do
      vp = VehiclePosition.new(speed: 0.5, bearing: 0.5, latitude: 1, longitude: 1)
      {:cont, new_vp} = filter(vp)
      assert VehiclePosition.speed(new_vp) == nil
      assert VehiclePosition.bearing(new_vp) == 0
    end

    test "other values are returned as-is" do
      assert {:cont, :value} = filter(:value)
    end
  end
end
