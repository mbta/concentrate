defmodule Concentrate.Encoder.VehiclePositionsTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.TestHelpers
  import Concentrate.Encoder.VehiclePositions
  alias Concentrate.StopTimeUpdate
  alias Concentrate.Parser.GTFSRealtime

  describe "encode/1 round trip" do
    test "decoding and re-encoding vehiclepositions.pb is a no-op" do
      decoded = GTFSRealtime.parse(File.read!(fixture_path("vehiclepositions.pb")))
      round_tripped = GTFSRealtime.parse(encode(decoded))
      assert round_tripped == decoded
    end

    test "ignores interspersed StopTimeUpdates" do
      decoded = GTFSRealtime.parse(File.read!(fixture_path("vehiclepositions.pb")))
      interspersed = Enum.intersperse(decoded, StopTimeUpdate.new(stop_id: "ignored"))
      round_tripped = GTFSRealtime.parse(encode(interspersed))
      assert round_tripped == decoded
    end
  end
end
