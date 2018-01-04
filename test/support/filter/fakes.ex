defmodule Concentrate.Filter.FakeTrips do
  @moduledoc "Fake implementation of Filter.GTFS.Trips"
  def route_id("trip"), do: "route"
  def route_id(_), do: nil

  def direction_id("trip"), do: 1
  def direction_id(_), do: nil
end

defmodule Concentrate.Filter.FakeCancelledTrips do
  @moduledoc "Fake implementation of Filter.Alerts.CancelledTrips"
  def trip_cancelled?("trip", {1970, 1, 1}) do
    true
  end

  def trip_cancelled?("trip", unix) do
    unix > 5 and unix < 10
  end

  def trip_cancelled?(_, _) do
    false
  end
end

defmodule Concentrate.Filter.FakeClosedStops do
  @moduledoc "Fake implementation of Filter.Alerts.ClosedStops"
  alias Concentrate.Alert.InformedEntity

  def stop_closed_for("stop", unix) do
    cond do
      unix < 5 ->
        []

      unix > 10 ->
        []

      true ->
        [
          InformedEntity.new(trip_id: "trip")
        ]
    end
  end

  def stop_closed_for("route_stop", _) do
    [
      InformedEntity.new(route_id: "other_route")
    ]
  end

  def stop_closed_for(_, _) do
    []
  end
end
