defmodule Concentrate.GroupFilter.Cache.VehicleBeforeStopTest do
  @moduledoc false
  use ExUnit.Case
  import Concentrate.GroupFilter.Cache.VehicleBeforeStop
  alias Concentrate.{VehiclePosition, StopTimeUpdate}

  defp supervised(_) do
    {:ok, _} = start_supervised(Concentrate.GroupFilter.Cache.VehicleBeforeStop)
    :ok
  end

  describe "stop_time_updates_for_vehicle/2" do
    setup :supervised

    test "restores older StopTimeUpdate values if the vehicle hasn't reached them" do
      trip_id = "before_stop_test"

      vp =
        VehiclePosition.new(
          id: "vehicle",
          trip_id: trip_id,
          stop_sequence: 1,
          latitude: 1.0,
          longitude: 1.0
        )

      stus =
        for stop_sequence <- 1..4 do
          StopTimeUpdate.new(trip_id: trip_id, stop_sequence: stop_sequence)
        end

      assert stop_time_updates_for_vehicle(vp, stus) == stus
      # restores the first two StopTimeUpdates since the vehicle hasn't
      # reached them
      assert stop_time_updates_for_vehicle(vp, Enum.drop(stus, 2)) == stus

      # restores the second StopTimeUpdate since the vehicle is past the
      # first one
      vp = VehiclePosition.update_stop_sequence(vp, 2)
      assert stop_time_updates_for_vehicle(vp, Enum.drop(stus, 2)) == Enum.drop(stus, 1)
    end

    test "uses updated stop time updates for future changes" do
      trip_id = "before_stop_test"

      vp =
        VehiclePosition.new(
          id: "vehicle",
          trip_id: trip_id,
          stop_sequence: 1,
          latitude: 1.0,
          longitude: 1.0
        )

      stus =
        for stop_sequence <- 1..4 do
          StopTimeUpdate.new(trip_id: trip_id, stop_sequence: stop_sequence)
        end

      assert stop_time_updates_for_vehicle(vp, stus) == stus
      vp = VehiclePosition.update_stop_sequence(vp, 2)

      new_stus =
        for stop_sequence <- 3..4 do
          StopTimeUpdate.new(trip_id: trip_id, stop_sequence: stop_sequence, arrival_time: 5)
        end

      # we expect one old update, plus the two new ones
      expected = Enum.slice(stus, 1..1) ++ new_stus
      assert stop_time_updates_for_vehicle(vp, new_stus) == expected
    end
  end

  describe "missing ETS table" do
    test "stop_time_updates_for_vehicle returns same updates" do
      vp = VehiclePosition.new(latitude: 1, longitude: 1)
      stu = StopTimeUpdate.new([])
      assert stop_time_updates_for_vehicle(vp, [stu]) == [stu]
    end
  end
end
