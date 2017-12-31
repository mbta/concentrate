defmodule Concentrate.Filter.GTFS.FirstLastStopSequenceTest do
  @moduledoc false
  use ExUnit.Case
  import Concentrate.Filter.GTFS.FirstLastStopSequence

  # copied + modified from a recent stop_times.txt
  @body """
  "trip_id","arrival_time","departure_time","stop_id","stop_sequence","stop_headsign","pickup_type","drop_off_type","timepoint","checkpoint_id"
  "Logan-22-Weekday-trip","08:00:00","08:00:00","Logan-Subway",1,"",0,1,0,""
  "Logan-22-Weekday-trip","08:04:00","08:04:00","Logan-RentalCarCenter",2,"",0,0,0,""
  "Logan-22-Weekday-trip","08:09:00","08:09:00","Logan-A",3,"",1,0,0,""
  "Logan-33-Weekday-trip","08:04:00","08:04:00","Logan-RentalCarCenter",2,"",2,2,0,""
  """

  setup do
    start_supervised(Concentrate.Filter.GTFS.FirstLastStopSequence)
    event = [{"stop_times.txt", @body}]
    # relies on being able to update the table from a different process
    handle_events([event], :ignored, :ignored)
    :ok
  end

  describe "pickup?" do
    test "true if there's a pickup at the stop on that trip" do
      assert pickup?("Logan-22-Weekday-trip", "Logan-Subway")
      assert pickup?("Logan-22-Weekday-trip", "Logan-RentalCarCenter")
      refute pickup?("Logan-22-Weekday-trip", "Logan-A")
      assert pickup?("Logan-33-Weekday-trip", "Logan-RentalCarCenter")
    end

    test "true if there's a pickup for that stop sequence" do
      assert pickup?("Logan-22-Weekday-trip", 1)
      assert pickup?("Logan-22-Weekday-trip", 2)
      refute pickup?("Logan-22-Weekday-trip", 3)
      assert pickup?("Logan-33-Weekday-trip", 2)
    end

    test "true for unknown trips" do
      assert pickup?("unknown trip", "unknown stop")
    end
  end

  describe "drop_off?" do
    test "true if there's a drop_off at the stop on that trip" do
      refute drop_off?("Logan-22-Weekday-trip", "Logan-Subway")
      assert drop_off?("Logan-22-Weekday-trip", "Logan-RentalCarCenter")
      assert drop_off?("Logan-22-Weekday-trip", "Logan-A")
      assert drop_off?("Logan-33-Weekday-trip", "Logan-RentalCarCenter")
    end

    test "true if there's a drop_off for that stop sequence" do
      refute drop_off?("Logan-22-Weekday-trip", 1)
      assert drop_off?("Logan-22-Weekday-trip", 2)
      assert drop_off?("Logan-22-Weekday-trip", 3)
      assert drop_off?("Logan-33-Weekday-trip", 2)
    end

    test "true for unknown trips" do
      assert drop_off?("unknown trip", "unknown stop")
    end
  end
end
