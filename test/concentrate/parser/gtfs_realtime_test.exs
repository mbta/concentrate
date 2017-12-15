defmodule Concentrate.Parser.GTFSRealtimeTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Parser.GTFSRealtime
  alias Concentrate.{VehiclePosition, TripUpdate, StopTimeUpdate}

  describe "parse/1" do
    test "parsing a vehiclepositions.pb file returns only VehiclePosition or TripUpdate structs" do
      binary = File.read!(fixture_path("vehiclepositions.pb"))
      parsed = parse(binary)
      assert [_ | _] = parsed

      for vp <- parsed do
        assert vp.__struct__ in [VehiclePosition, TripUpdate]
      end
    end

    test "parsing a tripupdates.pb file returns only StopTimeUpdate or TripUpdate structs" do
      binary = File.read!(fixture_path("tripupdates.pb"))
      parsed = parse(binary)
      assert [_ | _] = parsed

      for update <- parsed do
        assert update.__struct__ in [StopTimeUpdate, TripUpdate]
      end
    end
  end

  defp fixture_path(path) do
    fixture_path = Path.expand("../../fixtures", __DIR__)
    Path.expand(path, fixture_path)
  end
end
