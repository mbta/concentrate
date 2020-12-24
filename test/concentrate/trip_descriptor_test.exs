defmodule Concentrate.TripDescriptorTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.TripDescriptor
  alias Concentrate.Mergeable

  describe "Concentrate.Mergeable" do
    test "merge/2 takes non-nil values" do
      first =
        new(
          trip_id: "trip",
          route_id: "route",
          route_pattern_id: "pattern",
          start_date: {2017, 12, 20}
        )

      second =
        new(
          trip_id: "trip",
          direction_id: 0,
          start_time: "12:00:00",
          schedule_relationship: :ADDED
        )

      expected =
        new(
          trip_id: "trip",
          route_id: "route",
          route_pattern_id: "pattern",
          direction_id: 0,
          start_date: {2017, 12, 20},
          start_time: "12:00:00",
          schedule_relationship: :ADDED
        )

      assert Mergeable.merge(first, second) == expected
      assert Mergeable.merge(second, first) == expected
    end

    test "merge/2 prefers the later start date/time" do
      first =
        new(
          route_id: "route",
          start_date: {2020, 4, 14},
          start_time: "05:05:05"
        )

      second =
        new(
          route_pattern_id: "pattern",
          start_date: {2020, 4, 15},
          start_time: "05:05:04"
        )

      expected =
        new(
          route_id: "route",
          route_pattern_id: "pattern",
          start_date: {2020, 4, 15},
          start_time: "05:05:04"
        )

      assert Mergeable.merge(first, second) == expected
      assert Mergeable.merge(second, first) == expected
    end
  end
end
