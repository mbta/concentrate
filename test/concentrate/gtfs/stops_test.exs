defmodule Concentrate.GTFS.StopsTest do
  @moduledoc false
  use ExUnit.Case
  import Concentrate.GTFS.Stops

  @body """
  "stop_id","stop_code","stop_name","stop_desc","platform_code","platform_name","stop_lat","stop_lon","stop_address","zone_id","stop_url","level_id","location_type","parent_station","wheelchair_boarding"
  "South Station","","South Station","South Station - Commuter Rail","","Commuter Rail",42.35176309,-71.05479665,"","","","level_0_cr_platform",0,"place-sstat",1
  "place-sstat","","South Station","","","",42.352271,-71.055242,"","","","",1,"",1
  """

  defp supervised(_) do
    start_supervised!(Concentrate.GTFS.Stops)
    event = [{"stops.txt", @body}]
    # relies on being able to update the table from a different process
    handle_events([event], :ignored, :ignored)
    :ok
  end

  describe "parent_station_id/1" do
    setup :supervised

    test "returns the stop ID if it doesn't have a parent" do
      assert parent_station_id("5") == "5"
    end

    test "returns the parent ID for the parent itself" do
      assert parent_station_id("place-sstat") == "place-sstat"
    end

    test "returns the parent ID for a child" do
      assert parent_station_id("South Station") == "place-sstat"
    end
  end

  describe "missing ETS table" do
    test "parent_station_id/1 returns the given stop ID" do
      assert parent_station_id("missing") == "missing"
    end
  end
end
