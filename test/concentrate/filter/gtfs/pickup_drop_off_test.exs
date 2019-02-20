defmodule Concentrate.Filter.GTFS.PickupDropOffTest do
  @moduledoc false
  use ExUnit.Case
  import Concentrate.Filter.GTFS.PickupDropOff

  # copied + modified from a recent stop_times.txt
  @body """
  "trip_id","arrival_time","departure_time","stop_id","stop_sequence","stop_headsign","pickup_type","drop_off_type","timepoint","checkpoint_id"
  "Logan-22-Weekday-trip","08:00:00","08:00:00","Logan-Subway",1,"",0,1,0,""
  "Logan-22-Weekday-trip","08:04:00","08:04:00","Logan-RentalCarCenter",2,"",0,0,0,""
  "Logan-22-Weekday-trip","08:09:00","08:09:00","Logan-A",3,"",1,0,0,""
  "Logan-33-Weekday-trip","08:04:00","08:04:00","Logan-RentalCarCenter",2,"",2,2,0,""
  """

  defp supervised(_) do
    start_supervised(Concentrate.Filter.GTFS.PickupDropOff)
    event = [{"stop_times.txt", @body}]
    # relies on being able to update the table from a different process
    handle_events([event], :ignored, :ignored)
    :ok
  end

  describe "pickup?" do
    setup :supervised

    test "true if there's a pickup at the stop on that trip" do
      assert {true, _} = pickup_drop_off("Logan-22-Weekday-trip", "Logan-Subway")
      assert {true, _} = pickup_drop_off("Logan-22-Weekday-trip", "Logan-RentalCarCenter")
      assert {false, _} = pickup_drop_off("Logan-22-Weekday-trip", "Logan-A")
      assert {true, _} = pickup_drop_off("Logan-33-Weekday-trip", "Logan-RentalCarCenter")
    end

    test "true if there's a pickup for that stop sequence" do
      assert {true, _} = pickup_drop_off("Logan-22-Weekday-trip", 1)
      assert {true, _} = pickup_drop_off("Logan-22-Weekday-trip", 2)
      assert {false, _} = pickup_drop_off("Logan-22-Weekday-trip", 3)
      assert {true, _} = pickup_drop_off("Logan-33-Weekday-trip", 2)
    end

    test "unknown for unknown trips/stops" do
      assert pickup_drop_off("unknown trip", "unknown stop") == :unknown
      assert pickup_drop_off("Logan-33-Weekday-trip", "unknown stop") == :unknown
      assert pickup_drop_off("Logan-33-Weekday-trip", 4) == :unknown
    end
  end

  describe "drop_off?" do
    setup :supervised

    test "true if there's a drop_off at the stop on that trip" do
      assert {_, false} = pickup_drop_off("Logan-22-Weekday-trip", "Logan-Subway")
      assert {_, true} = pickup_drop_off("Logan-22-Weekday-trip", "Logan-RentalCarCenter")
      assert {_, true} = pickup_drop_off("Logan-22-Weekday-trip", "Logan-A")
      assert {_, true} = pickup_drop_off("Logan-33-Weekday-trip", "Logan-RentalCarCenter")
    end

    test "true if there's a drop_off for that stop sequence" do
      assert {_, false} = pickup_drop_off("Logan-22-Weekday-trip", 1)
      assert {_, true} = pickup_drop_off("Logan-22-Weekday-trip", 2)
      assert {_, true} = pickup_drop_off("Logan-22-Weekday-trip", 3)
      assert {_, true} = pickup_drop_off("Logan-33-Weekday-trip", 2)
    end

    test "unknown for unknown trips" do
      assert pickup_drop_off("unknown trip", "unknown stop") == :unknown
    end
  end

  describe "missing ETS table" do
    test "pickup_drop_off is unknown" do
      assert pickup_drop_off("trip", 1) == :unknown
    end
  end
end
