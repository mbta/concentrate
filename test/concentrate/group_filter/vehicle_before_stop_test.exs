defmodule Concentrate.GroupFilter.VehicleBeforeStopTest do
  @moduledoc false
  use ExUnit.Case
  import Concentrate.GroupFilter.VehicleBeforeStop
  alias Concentrate.{TripUpdate, VehiclePosition, StopTimeUpdate}

  describe "filter/1" do
    setup do
      {:ok, _} = start_supervised(Concentrate.GroupFilter.Cache.VehicleBeforeStop)
      :ok
    end

    test "restores older StopTimeUpdate values if the vehicle hasn't reached them yet" do
      trip_id = "before_stop_test"
      tu = TripUpdate.new(trip_id: trip_id)

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

      group = {tu, [vp], stus}
      assert filter(group) == group
      # restores the first two StopTimeUpdates since the vehicle hasn't
      # reached them
      assert filter({tu, [vp], Enum.drop(stus, 2)}) == group

      # restores the second StopTimeUpdate since the vehicle is past the
      # first one
      vp = VehiclePosition.update_stop_sequence(vp, 2)
      assert filter({tu, [vp], Enum.drop(stus, 2)}) == {tu, [vp], Enum.drop(stus, 1)}
    end

    test "ignores unknown values" do
      assert filter(:value) == :value
    end
  end
end
