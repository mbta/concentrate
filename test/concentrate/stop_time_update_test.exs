defmodule Concentrate.StopTimeUpdateTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.StopTimeUpdate
  alias Concentrate.Mergeable

  describe "Concentrate.Mergeable" do
    test "merge/2 takes non-nil values, earliest arrival, latest departure" do
      first =
        new(
          trip_id: "trip",
          stop_id: "stop",
          stop_sequence: 1,
          arrival_time: 2,
          departure_time: 3,
          status: "status",
          platform_id: "platform"
        )

      second =
        new(
          trip_id: "trip",
          stop_id: "stop",
          stop_sequence: 1,
          arrival_time: 1,
          departure_time: 4,
          track: "track",
          schedule_relationship: :SKIPPED
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
          platform_id: "platform"
        )

      assert Mergeable.merge(first, second) == expected
      assert Mergeable.merge(second, first) == expected
    end
  end
end
