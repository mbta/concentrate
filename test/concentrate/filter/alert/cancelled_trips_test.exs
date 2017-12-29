defmodule Concentrate.Filter.Alert.CancelledTripsTest do
  @moduledoc false
  use ExUnit.Case
  import Concentrate.Filter.Alert.CancelledTrips
  alias Concentrate.{Alert, Alert.InformedEntity}

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
            {DateTime.from_unix!(5), DateTime.from_unix!(10)},
            {DateTime.from_unix!(15), DateTime.from_unix!(20)}
          ],
          informed_entity: [
            InformedEntity.new(trip_id: "trip_with_stop", stop_id: "stop"),
            InformedEntity.new(trip_id: "trip_with_route", route_id: "route")
          ]
        )

      handle_events([[alert]], :from, :state)

      assert trip_cancelled?("trip_with_route", DateTime.from_unix!(5))
      refute trip_cancelled?("trip_with_stop", DateTime.from_unix!(20))
      assert trip_cancelled?("trip_with_route", ~D[1970-01-01])
    end

    test "correct handles start/stop date times across date boundaries" do
      one_day = 86_400

      alert =
        Alert.new(
          effect: :NO_SERVICE,
          active_period: [
            {DateTime.from_unix!(one_day - 5), DateTime.from_unix!(one_day + 5)}
          ],
          informed_entity: [
            InformedEntity.new(trip_id: "trip")
          ]
        )

      handle_events([[alert]], :from, :state)

      assert trip_cancelled?("trip", ~D[1970-01-01])
      assert trip_cancelled?("trip", ~D[1970-01-02])
      refute trip_cancelled?("trip", ~D[1970-01-03])
      assert trip_cancelled?("trip", DateTime.from_unix!(one_day - 1))
      assert trip_cancelled?("trip", DateTime.from_unix!(one_day + 1))
      refute trip_cancelled?("trip", DateTime.from_unix!(one_day - 10))
      refute trip_cancelled?("trip", DateTime.from_unix!(one_day + 10))
    end
  end
end
