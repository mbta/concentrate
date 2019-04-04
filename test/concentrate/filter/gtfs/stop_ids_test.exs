defmodule Concentrate.Filter.GTFS.StopIDsTest do
  @moduledoc false
  use ExUnit.Case
  import Concentrate.Filter.GTFS.StopIDs

  # copied + modified from a recent stop_times.txt
  @body """
  "trip_id","arrival_time","departure_time","stop_id","stop_sequence","stop_headsign","pickup_type","drop_off_type","timepoint","checkpoint_id"
  "Logan-22-Weekday-trip","08:00:00","08:00:00","Logan-Subway",1,"",0,1,0,""
  """

  defp supervised(_) do
    start_supervised(Concentrate.Filter.GTFS.StopIDs)
    event = [{"stop_times.txt", @body}]
    # relies on being able to update the table from a different process
    handle_events([event], :ignored, :ignored)
    :ok
  end

  describe "stop_id" do
    setup :supervised

    test "stop ID for the trip/sequence" do
      assert stop_id("Logan-22-Weekday-trip", 1) == "Logan-Subway"
    end

    test "unknown for unknown trips/stops" do
      assert stop_id("unknown trip", 1) == :unknown
      assert stop_id("Logan-22-Weekday-trip", 4) == :unknown
    end
  end

  describe "missing ETS table" do
    test "stop_id is unknown" do
      assert stop_id("trip", 1) == :unknown
    end
  end
end
