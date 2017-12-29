defmodule Concentrate.Filter.VehiclePastStopTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Filter.VehiclePastStop
  alias Concentrate.{VehiclePosition, StopTimeUpdate}

  @state %{}

  describe "filter/2" do
    test "removes StopTimeUpdates if they come after the vehicle's sequence" do
      vp = VehiclePosition.new(trip_id: "trip", stop_sequence: 5, latitude: 1, longitude: 1)
      assert {:cont, ^vp, state} = filter(vp, @state)
      # ignores different trip IDs
      stu = StopTimeUpdate.new(trip_id: "ignored", stop_sequence: 6)
      assert {:cont, ^stu, state} = filter(stu, state)
      # keeps updates without a stop sequence
      stu = StopTimeUpdate.new(trip_id: "trip")
      assert {:cont, ^stu, state} = filter(stu, state)
      # keeps updates that are at the stop
      stu = StopTimeUpdate.new(trip_id: "trip", stop_sequence: 5)
      assert {:cont, ^stu, state} = filter(stu, state)
      # removes updates that are before the stop
      stu = StopTimeUpdate.new(trip_id: "trip", stop_sequence: 4)
      assert {:skip, _state} = filter(stu, state)
    end

    test "vehicles without a stop sequence are ignored" do
      vp = VehiclePosition.new(trip_id: "trip", latitude: 1, longitude: 1)
      assert {:cont, ^vp, state} = filter(vp, @state)
      assert state == %{}
    end

    test "other values are returned as-is" do
      assert {:cont, :value, _} = filter(:value, @state)
    end
  end
end
