defmodule Concentrate.Filter.CancelledTripTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Filter.CancelledTrip
  alias Concentrate.{TripUpdate, StopTimeUpdate}

  @state Concentrate.Filter.FakeCancelledTrips

  describe "filter/2" do
    test "TripUpdate is cancelled if the start date matches" do
      tu =
        TripUpdate.new(
          trip_id: "trip",
          start_date: ~D[1970-01-01]
        )

      assert {:cont, new_tu, _} = filter(tu, @state)
      assert TripUpdate.schedule_relationship(new_tu) == :CANCELED
    end

    test "TripUpdate is not cancelled if the start date does not match" do
      tu =
        TripUpdate.new(
          trip_id: "trip",
          start_date: ~D[1970-01-02]
        )

      assert {:cont, ^tu, _} = filter(tu, @state)
    end

    test "TripUpdate is not cancelled if the trip ID does not match" do
      tu =
        TripUpdate.new(
          trip_id: "other trip",
          start_date: ~D[1970-01-01]
        )

      assert {:cont, ^tu, _} = filter(tu, @state)
    end

    test "StopTimeUpdate is skipped if the trip ID and time match" do
      stu =
        StopTimeUpdate.new(
          trip_id: "trip",
          arrival_time: DateTime.from_unix!(8)
        )

      assert {:cont, new_stu, _} = filter(stu, @state)
      assert new_stu == StopTimeUpdate.skip(stu)
    end

    test "StopTimeUpdate is not skipped if the time does not match" do
      stu =
        StopTimeUpdate.new(
          trip_id: "trip",
          arrival_time: DateTime.from_unix!(50)
        )

      assert {:cont, ^stu, _} = filter(stu, @state)
    end

    test "other values are returned as-is" do
      assert {:cont, :value, _} = filter(:value, @state)
    end
  end
end
