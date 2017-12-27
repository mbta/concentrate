defmodule Concentrate.Filter.GTFS.FirstLastStopSequenceTest do
  @moduledoc false
  use ExUnit.Case
  import Concentrate.Filter.GTFS.FirstLastStopSequence

  # copied from a recent stop_times.txt
  @body """
  "trip_id","arrival_time","departure_time","stop_id","stop_sequence","stop_headsign","pickup_type","drop_off_type","timepoint","checkpoint_id"
  "Logan-22-Weekday-trip","08:00:00","08:00:00","Logan-Subway",1,"",0,1,0,""
  "Logan-22-Weekday-trip","08:04:00","08:04:00","Logan-RentalCarCenter",2,"",0,0,0,""
  "Logan-22-Weekday-trip","08:09:00","08:09:00","Logan-A",3,"",0,0,0,""
  "Logan-33-Weekday-trip","08:04:00","08:04:00","Logan-RentalCarCenter",2,"",0,0,0,""
  """

  setup do
    start_supervised(Concentrate.Filter.GTFS.FirstLastStopSequence)
    event = [{"stop_times.txt", @body}]
    # relies on being able to update the table from a different process
    handle_events([event], :ignored, :ignored)
    :ok
  end

  describe "stop_sequences/1" do
    test "returns the first and last stop sequence id for the given trip" do
      assert stop_sequences("Logan-22-Weekday-trip") == {1, 3}
      assert stop_sequences("unknown") == nil
    end
  end
end
