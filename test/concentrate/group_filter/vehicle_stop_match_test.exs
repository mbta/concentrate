defmodule Concentrate.GroupFilter.VehicleStopMatchTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.GroupFilter.VehicleStopMatch
  alias Concentrate.{StopTimeUpdate, VehiclePosition}
  alias Concentrate.GTFS.Stops

  describe "filter/1" do
    test "updates the VehiclePosition stop_id to match the StopTimeUpdate" do
      start_supervised!(Stops)
      Stops._insert_mapping("child1", "parent")
      Stops._insert_mapping("child2", "parent")

      vp = VehiclePosition.new(stop_id: "child1", stop_sequence: 2, latitude: 1, longitude: 2)

      stus = [
        StopTimeUpdate.new(stop_id: "first", stop_sequence: 1),
        StopTimeUpdate.new(stop_id: "child2", stop_sequence: 2)
      ]

      {_, [new_vp], _} = filter({nil, [vp], stus})

      assert VehiclePosition.stop_id(new_vp) == "child2"
    end

    test "does not update if the parent station's don't match" do
      vp = VehiclePosition.new(stop_id: "child1", stop_sequence: 1, latitude: 1, longitude: 2)

      stus = [
        StopTimeUpdate.new(stop_id: "other", stop_sequence: 1)
      ]

      assert {_, [^vp], _} = filter({nil, [vp], stus})
    end

    test "does nothing if the stop IDs already match" do
      vp = VehiclePosition.new(stop_id: "stop", stop_sequence: 1, latitude: 1, longitude: 2)

      stus = [
        StopTimeUpdate.new(stop_id: "stop", stop_sequence: 1)
      ]

      assert {_, [^vp], _} = filter({nil, [vp], stus})
    end

    test "does nothing if we can't find a matching stop_sequence" do
      vp = VehiclePosition.new(stop_id: "child1", stop_sequence: 1, latitude: 1, longitude: 2)
      assert {_, [^vp], _} = filter({nil, [vp], []})
    end

    test "does nothing if either of the stop IDs are nil" do
      vp = VehiclePosition.new(stop_id: nil, stop_sequence: 1, latitude: 1, longitude: 2)

      stus = [
        StopTimeUpdate.new(stop_id: "other", stop_sequence: 1)
      ]

      assert {_, [^vp], _} = filter({nil, [vp], stus})

      vp = VehiclePosition.new(stop_id: "other", stop_sequence: 1, latitude: 1, longitude: 2)

      stus = [
        StopTimeUpdate.new(stop_id: nil, stop_sequence: 1)
      ]

      assert {_, [^vp], _} = filter({nil, [vp], stus})
    end
  end
end
