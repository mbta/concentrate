defmodule Concentrate.Parser.GTFSRealtimeTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.TestHelpers
  import Concentrate.Parser.GTFSRealtime
  alias Concentrate.Parser.GTFSRealtime
  alias Concentrate.{VehiclePosition, TripUpdate, StopTimeUpdate}

  describe "parse/1" do
    test "parsing a vehiclepositions.pb file returns only VehiclePosition or TripUpdate structs" do
      binary = File.read!(fixture_path("vehiclepositions.pb"))
      parsed = parse(binary)
      assert [_ | _] = parsed

      for vp <- parsed do
        assert vp.__struct__ in [VehiclePosition, TripUpdate]
      end
    end

    test "parsing a tripupdates.pb file returns only StopTimeUpdate or TripUpdate structs" do
      binary = File.read!(fixture_path("tripupdates.pb"))
      parsed = parse(binary)
      assert [_ | _] = parsed

      for update <- parsed do
        assert update.__struct__ in [StopTimeUpdate, TripUpdate]
      end
    end
  end

  describe "decode_trip_update/1" do
    test "test can handle nil times as well as nil events" do
      update = %GTFSRealtime.TripUpdate{
        trip: %GTFSRealtime.TripDescriptor{},
        stop_time_update: [
          %GTFSRealtime.TripUpdate.StopTimeUpdate{
            arrival: nil,
            departure: %GTFSRealtime.TripUpdate.StopTimeEvent{}
          }
        ]
      }

      [_tu, stop_update] = decode_trip_update(update)
      refute StopTimeUpdate.arrival_time(stop_update)
      refute StopTimeUpdate.departure_time(stop_update)
    end
  end
end
