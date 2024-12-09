defmodule Concentrate.Filter.Alert.ClosedStopsTest do
  @moduledoc false
  use ExUnit.Case
  import Concentrate.Filter.Alert.ClosedStops
  alias Concentrate.{Alert, Alert.InformedEntity}

  defp supervised(_) do
    start_supervised(Concentrate.Filter.Alert.ClosedStops)
    :ok
  end

  describe "stop_closed_for/3" do
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
            stop_route = InformedEntity.new(stop_id: "other", route_id: "route"),
            stop_route_2 = InformedEntity.new(stop_id: "other", route_id: "route 2")
          ]
        )

      handle_events([[alert]], :from, :state)

      assert stop_closed_for("stop", "route", 5) == [stop_only]
      assert stop_closed_for("stop", "other_route", 5) == [stop_only]
      assert stop_closed_for("other", "route", 20) == [stop_route]
      assert stop_closed_for("other", "route 2", 20) == [stop_route_2]
      assert stop_closed_for("other", "other_route", 20) == []
      assert stop_closed_for("stop", "route", 12) == []
      assert stop_closed_for("unknown", "route", 8) == []
    end

    test "for route types 3 and 4, :DETOUR is also a closed stop" do
      alert =
        Alert.new(
          effect: :DETOUR,
          active_period: [
            {5, 10}
          ],
          informed_entity: [
            InformedEntity.new(stop_id: "light_rail", route_type: 0),
            InformedEntity.new(stop_id: "heavy_rail", route_type: 1),
            InformedEntity.new(stop_id: "commuter_rail", route_type: 2),
            bus = InformedEntity.new(stop_id: "bus", route_type: 3),
            ferry = InformedEntity.new(stop_id: "ferry", route_type: 4)
          ]
        )

      handle_events([[alert]], :from, :state)

      assert stop_closed_for("bus", "bus_route", 5) == [bus]
      assert stop_closed_for("ferry", "ferry_route", 6) == [ferry]

      for name <- ~w(light_rail heavy_rail commuter_rail) do
        assert stop_closed_for(name, "#{name}_route", 6) == []
      end
    end
  end

  describe "missing ETS table" do
    test "stop_closed_for/2 returns empty list" do
      assert stop_closed_for("stop", "route", 0) == []
    end
  end
end
