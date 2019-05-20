defmodule Concentrate.StopTimeUpdateTest do
  @moduledoc false
  use ExUnit.Case
  import Concentrate.StopTimeUpdate
  alias Concentrate.Mergeable

  @stu new(
         trip_id: "trip",
         stop_id: "stop",
         stop_sequence: 1,
         arrival_time: 2,
         departure_time: 3,
         status: "status",
         platform_id: "platform"
       )

  describe "skip/1" do
    test "removes the times/status" do
      skipped = skip(@stu)
      assert time(skipped) == nil
      assert status(skipped) == nil
    end

    test "sets the relationship to SKIPPED" do
      skipped = skip(@stu)
      assert schedule_relationship(skipped) == :SKIPPED
    end
  end

  describe "Concentrate.Mergeable" do
    test "key/1 uses the parent station ID" do
      start_supervised!(Concentrate.Filter.GTFS.Stops)
      Concentrate.Filter.GTFS.Stops._insert_mapping("child_id", "parent_id")

      assert Mergeable.key(new(stop_id: "child_id")) == {nil, "parent_id", nil}
      assert Mergeable.key(new(stop_id: "other")) == {nil, "other", nil}
      assert Mergeable.key(new(stop_id: nil)) == {nil, nil, nil}
    end

    test "merge/2 takes non-nil values, earliest arrival, latest departure" do
      first = @stu

      second =
        new(
          trip_id: "trip",
          stop_id: "stop-01",
          stop_sequence: 1,
          arrival_time: 1,
          departure_time: 4,
          track: "track",
          schedule_relationship: :SKIPPED,
          uncertainty: 300
        )

      expected =
        new(
          trip_id: "trip",
          stop_id: "stop-01",
          stop_sequence: 1,
          arrival_time: 1,
          departure_time: 4,
          status: "status",
          track: "track",
          schedule_relationship: :SKIPPED,
          platform_id: "platform",
          uncertainty: 300
        )

      assert Mergeable.merge(first, second) == expected
      assert Mergeable.merge(second, first) == expected
    end
  end
end
