defmodule Concentrate.Encoder.TripUpdatesTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.TestHelpers
  import Concentrate.Encoder.TripUpdates
  alias Concentrate.VehiclePosition
  alias Concentrate.Parser.GTFSRealtime

  describe "encode/1 round trip" do
    test "decoding and re-encoding tripupdates.pb is a no-op" do
      decoded = GTFSRealtime.parse(File.read!(fixture_path("tripupdates.pb")))
      round_tripped = GTFSRealtime.parse(encode(decoded))
      assert round_tripped == decoded
    end

    test "interspersing VehiclePositions doesn't affect the output (with non-matching trips)" do
      decoded = GTFSRealtime.parse(File.read!(fixture_path("tripupdates.pb")))

      interspersed =
        Enum.intersperse(
          decoded,
          VehiclePosition.new(trip_id: "non_matching", latitude: 1, longitude: 1)
        )

      round_tripped = GTFSRealtime.parse(encode(interspersed))
      assert round_tripped == decoded
    end
  end
end
