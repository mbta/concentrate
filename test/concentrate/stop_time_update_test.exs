defmodule Concentrate.StopTimeUpdateTest do
  @moduledoc false
  use ExUnit.Case
  import Concentrate.StopTimeUpdate
  alias Concentrate.Mergeable

  @stu new(
         trip_id: "trip",
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
    test "takes non-nil values, earliest arrival, latest departure" do
      first = @stu

      second =
        new(
          trip_id: "trip",
          stop_id: "stop",
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
          stop_id: "stop",
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

    test "picks the 'greater' of two stop IDs" do
      first = new(stop_id: "stop")
      second = new(stop_id: "stop-01")

      assert %{stop_id: "stop-01"} = Mergeable.merge(first, second)
      assert %{stop_id: "stop-01"} = Mergeable.merge(second, first)
    end
  end
end
