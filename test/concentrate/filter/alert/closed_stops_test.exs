defmodule Concentrate.Filter.Alert.ClosedStopsTest do
  @moduledoc false
  use ExUnit.Case
  import Concentrate.Filter.Alert.ClosedStops
  alias Concentrate.{Alert, Alert.InformedEntity}

  defp supervised(_) do
    start_supervised(Concentrate.Filter.Alert.ClosedStops)
    :ok
  end

  describe "stop_closed_for/2" do
    setup :supervised

    test "returns a list of entities for which the stop is closed at the given time" do
      alert =
        Alert.new(
          effect: :NO_SERVICE,
          active_period: [
            {5, 10},
            {15, 20}
          ],
          informed_entity: [
            stop_only = InformedEntity.new(stop_id: "stop"),
            stop_route = InformedEntity.new(stop_id: "other", route_id: "route")
          ]
        )

      handle_events([[alert]], :from, :state)

      assert stop_closed_for("stop", 5) == [stop_only]
      assert stop_closed_for("other", 20) == [stop_route]
      assert stop_closed_for("stop", 12) == []
      assert stop_closed_for("unknown", 8) == []
    end
  end

  describe "missing ETS table" do
    test "stop_closed_for/2 returns empty list" do
      assert stop_closed_for("stop", 0) == []
    end
  end
end
