defmodule Concentrate.Parser.HelpersTest do
  use ExUnit.Case, async: true
  import Concentrate.Parser.Helpers
  alias Concentrate.{TripUpdate, VehiclePosition}

  describe "drop_fields/2" do
    @options parse_options(
               drop_fields: %{
                 VehiclePosition => [:speed]
               }
             )
    test "drops fields from the provided configuration" do
      tu = TripUpdate.new(trip_id: "trip")

      vp =
        VehiclePosition.new(
          id: "1",
          latitude: 1,
          longitude: 2,
          speed: 5
        )

      assert [^tu, new_vp] = drop_fields([tu, vp], @options.drop_fields)
      assert VehiclePosition.speed(new_vp) == nil
    end
  end
end
