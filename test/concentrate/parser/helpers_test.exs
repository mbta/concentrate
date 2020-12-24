defmodule Concentrate.Parser.HelpersTest do
  use ExUnit.Case, async: true
  import Concentrate.Parser.Helpers
  alias Concentrate.{TripDescriptor, VehiclePosition}

  describe "drop_fields/2" do
    @options parse_options(
               drop_fields: %{
                 VehiclePosition => [:speed]
               }
             )
    test "drops fields from the provided configuration" do
      td = TripDescriptor.new(trip_id: "trip")

      vp =
        VehiclePosition.new(
          id: "1",
          latitude: 1,
          longitude: 2,
          speed: 5.2
        )

      assert [^td, new_vp] = drop_fields([td, vp], @options.drop_fields)
      assert VehiclePosition.speed(new_vp) == nil
    end
  end

  describe "parse_options/1" do
    test "handles feed_url option" do
      assert %Concentrate.Parser.Helpers.Options{feed_url: "url"} =
               Concentrate.Parser.Helpers.parse_options(feed_url: "url")
    end
  end
end
