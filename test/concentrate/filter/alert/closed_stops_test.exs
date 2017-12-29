defmodule Concentrate.Filter.Alert.ClosedStopsTest do
  @moduledoc false
  use ExUnit.Case
  import Concentrate.Filter.Alert.ClosedStops
  alias Concentrate.{Alert, Alert.InformedEntity}

  setup do
    start_supervised(Concentrate.Filter.Alert.ClosedStops)
    :ok
  end

  describe "stop_closed_for/2" do
    test "returns a list of entities for which the stop is closed at the given time" do
      alert =
        Alert.new(
          effect: :NO_SERVICE,
          active_period: [
            {DateTime.from_unix!(5), DateTime.from_unix!(10)},
            {DateTime.from_unix!(15), DateTime.from_unix!(20)}
          ],
          informed_entity: [
            stop_only = InformedEntity.new(stop_id: "stop"),
            stop_route = InformedEntity.new(stop_id: "other", route_id: "route")
          ]
        )

      handle_events([[alert]], :from, :state)

      assert stop_closed_for("stop", DateTime.from_unix!(5)) == [stop_only]
      assert stop_closed_for("other", DateTime.from_unix!(20)) == [stop_route]
      assert stop_closed_for("stop", DateTime.from_unix!(12)) == []
      assert stop_closed_for("unknown", DateTime.from_unix!(8)) == []
    end
  end
end
