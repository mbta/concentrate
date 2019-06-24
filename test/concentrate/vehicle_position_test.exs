defmodule Concentrate.VehiclePositionTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.VehiclePosition
  alias Concentrate.Mergeable
  alias Concentrate.VehiclePosition.Consist

  describe "Concentrate.Mergeable" do
    test "merge/2 takes the latest of the two positions" do
      first = new(last_updated: 1, latitude: 1, longitude: 1, trip_id: "trip")
      second = new(last_updated: 2, latitude: 2, longitude: 2)
      expected = new(last_updated: 2, latitude: 2, longitude: 2, trip_id: "trip")
      assert Mergeable.merge(first, second) == expected
      assert Mergeable.merge(second, first) == expected
    end

    test "merge/2 takes a consist list in preference to an empty list" do
      consist = [Consist.new(label: "vehicle")]
      first = new(last_updated: 1, latitude: 1, longitude: 1, consist: consist)
      expected = new(last_updated: 2, latitude: 2, longitude: 2, consist: consist)

      for second_value <- [[], nil] do
        second = new(last_updated: 2, latitude: 2, longitude: 2, consist: second_value)
        assert Mergeable.merge(first, second) == expected
        assert Mergeable.merge(second, first) == expected
      end
    end
  end
end
