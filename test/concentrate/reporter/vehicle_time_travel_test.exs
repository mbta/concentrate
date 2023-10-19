defmodule Concentrate.Reporter.VehicleTimeTravelTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Concentrate.Reporter.VehicleTimeTravel
  alias Concentrate.{TripDescriptor, VehiclePosition}

  setup do
    %{state: VehicleTimeTravel.init()}
  end

  describe "log/2" do
    test "logs an event if a vehicle has a timestamp which goes back in time", %{state: state} do
      check all(group1 <- group(), group2 <- group()) do
        log =
          ExUnit.CaptureLog.capture_log(fn -> VehicleTimeTravel.log([group1, group2], state) end)

        case {group1, group2} do
          {{_, [%{id: vehicle_id, last_updated: t1} = vp1], _},
           {_, [%{id: vehicle_id, last_updated: t2} = vp2], _}}
          when t1 > t2 ->
            assert log =~ "event=vehicle_time_travel"
            assert log =~ "vehicle_id=#{vehicle_id}"
            assert log =~ "trip_id=#{VehiclePosition.trip_id(vp2)}"
            assert log =~ "later=#{VehiclePosition.last_updated(vp1)}"
            assert log =~ "earlier=#{VehiclePosition.last_updated(vp2)}"

          _ ->
            refute log =~ "event=vehicle_time_travel"
        end
      end
    end
  end

  defp group do
    gen all(
          trip_id <- trip_id(),
          vehicle_ids <- list_of(vehicle_id(), max_length: 1),
          timestamp <- integer(0..2)
        ) do
      td = TripDescriptor.new(trip_id: trip_id)

      vps =
        for vehicle_id <- vehicle_ids do
          VehiclePosition.new(
            id: vehicle_id,
            latitude: 0,
            longitude: 0,
            last_updated: timestamp,
            trip_id: trip_id
          )
        end

      stus = []
      {td, vps, stus}
    end
  end

  def trip_id do
    ["trip_a", "trip_b"]
    |> Enum.map(&constant/1)
    |> one_of
  end

  def vehicle_id do
    ["v1", "v2"]
    |> Enum.map(&constant/1)
    |> one_of
  end
end
