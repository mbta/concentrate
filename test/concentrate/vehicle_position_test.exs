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
      expected = first

      for second_value <- [[], nil] do
        second = new(last_updated: 1, latitude: 1, longitude: 1, consist: second_value)
        assert Mergeable.merge(first, second) == expected
        assert Mergeable.merge(second, first) == expected
      end
    end

    test "merge/2 merges the status/stop_sequence data" do
      first =
        new(last_updated: 1, latitude: 1, longitude: 1, status: :STOPPED_AT, stop_sequence: 3)

      second = new(last_updated: 2, latitude: 2, longitude: 2)

      expected =
        new(
          last_updated: 2,
          latitude: 2,
          longitude: 2,
          status: :STOPPED_AT,
          stop_sequence: 3
        )

      assert Mergeable.merge(first, second) == expected
      assert Mergeable.merge(second, first) == expected
    end

    test "merge/2 merges the occupancy status information" do
      first = new(last_updated: 1, latitude: 1, longitude: 1, occupancy_status: :MANY_SEATS_FULL)
      second = new(last_updated: 2, latitude: 2, longitude: 2, occupancy_percentage: 50)

      expected =
        new(
          last_updated: 2,
          latitude: 2,
          longitude: 2,
          occupancy_status: :MANY_SEATS_FULL,
          occupancy_percentage: 50
        )

      assert Mergeable.merge(first, second) == expected
      assert Mergeable.merge(second, first) == expected
    end

    test "merge/2 merges the multi carriage status information" do
      first =
        new(
          last_updated: 1,
          latitude: 1,
          longitude: 1,
          multi_carriage_details: [
            %{
              id: 0,
              label: "main-car",
              occupancy_status: :MANY_SEATS_FULL,
              occupancy_percentage: 80,
              carriage_sequence: 1,
              orientation: :AB
            },
            %{
              id: 0,
              label: "second-car",
              occupancy_status: :EMPTY,
              occupancy_percentage: 0,
              carriage_sequence: 2,
              orientation: :BA
            }
          ]
        )

      second = new(last_updated: 2, latitude: 2, longitude: 2)

      expected =
        new(
          last_updated: 2,
          latitude: 2,
          longitude: 2,
          multi_carriage_details: [
            %{
              id: 0,
              label: "main-car",
              occupancy_status: :MANY_SEATS_FULL,
              occupancy_percentage: 80,
              carriage_sequence: 1,
              orientation: :AB
            },
            %{
              id: 0,
              label: "second-car",
              occupancy_status: :EMPTY,
              occupancy_percentage: 0,
              carriage_sequence: 2,
              orientation: :BA
            }
          ]
        )

      assert Mergeable.merge(first, second) == expected
      assert Mergeable.merge(second, first) == expected
    end
  end
end
