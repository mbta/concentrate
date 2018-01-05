defmodule Concentrate.Filter.Alert.CancelledTripsTest do
  @moduledoc false
  use ExUnit.Case
  import Concentrate.Filter.Alert.CancelledTrips
  alias Concentrate.{Alert, Alert.InformedEntity}

  @one_day 86_400

  setup do
    start_supervised(Concentrate.Filter.Alert.CancelledTrips)
    :ok
  end

  describe "trip_cancelled?/2" do
    test "returns a boolean indicating whether the trip is cancelled at the given date or time" do
      alert =
        Alert.new(
          effect: :NO_SERVICE,
          active_period: [
            {5, 10},
            {15, 20}
          ],
          informed_entity: [
            InformedEntity.new(trip_id: "trip_with_stop", stop_id: "stop"),
            InformedEntity.new(trip_id: "trip_with_route", route_id: "route")
          ]
        )

      handle_events([[alert]], :from, :state)

      assert trip_cancelled?("trip_with_route", 5)
      refute trip_cancelled?("trip_with_stop", 20)
      assert trip_cancelled?("trip_with_route", {1970, 1, 1})
    end

    test "correct handles start/stop date times across date boundaries" do
      alert =
        Alert.new(
          effect: :NO_SERVICE,
          active_period: [
            {@one_day - 5, @one_day + 5}
          ],
          informed_entity: [
            InformedEntity.new(trip_id: "trip")
          ]
        )

      handle_events([[alert]], :from, :state)

      assert trip_cancelled?("trip", {1970, 1, 1})
      assert trip_cancelled?("trip", {1970, 1, 2})
      refute trip_cancelled?("trip", {1970, 1, 3})
      assert trip_cancelled?("trip", @one_day - 1)
      assert trip_cancelled?("trip", @one_day + 1)
      refute trip_cancelled?("trip", @one_day - 10)
      refute trip_cancelled?("trip", @one_day + 10)
    end

    test "correctly handles long term cancellations" do
      alert =
        Alert.new(
          effect: :NO_SERVICE,
          active_period: [
            {@one_day + 1, @one_day * 10}
          ],
          informed_entity: [
            InformedEntity.new(trip_id: "trip")
          ]
        )

      handle_events([[alert]], :from, :state)

      refute trip_cancelled?("trip", {1970, 1, 1})
      refute trip_cancelled?("trip", 0)
      refute trip_cancelled?("trip", @one_day)

      for i <- 2..4 do
        assert trip_cancelled?("trip", {1970, 1, i})
        assert trip_cancelled?("trip", @one_day * i)
      end
    end
  end

  describe "route_cancelled?/1" do
    test "returns a boolean indicating whether the route is cancelled at the given date or time" do
      alert =
        Alert.new(
          effect: :NO_SERVICE,
          active_period: [
            {5, 10},
            {15, 20}
          ],
          informed_entity: [
            InformedEntity.new(route_id: "route_alone"),
            InformedEntity.new(trip_id: "trip_with_route", route_id: "route")
          ]
        )

      handle_events([[alert]], :from, :state)

      assert route_cancelled?("route_alone", 5)
      refute route_cancelled?("route", 20)
      assert route_cancelled?("route_alone", {1970, 1, 1})
    end
  end
end
