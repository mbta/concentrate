defmodule Concentrate.Parser.GTFSRealtimeTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.TestHelpers
  import Concentrate.Parser.GTFSRealtime
  alias Concentrate.Parser.GTFSRealtime
  alias Concentrate.{VehiclePosition, TripUpdate, StopTimeUpdate, Alert}

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

    test "parsing an alerts.pb returns only alerts" do
      binary = File.read!(fixture_path("alerts.pb"))
      parsed = parse(binary)
      assert [_ | _] = parsed

      for alert <- parsed do
        assert alert.__struct__ == Alert
      end
    end
  end

  describe "decode_trip_update/1" do
    test "parses the trip descriptor" do
      update = %GTFSRealtime.TripUpdate{
        trip: %GTFSRealtime.TripDescriptor{
          trip_id: "trip",
          route_id: "route",
          direction_id: 1,
          start_date: "20171220",
          start_time: "26:15:09",
          schedule_relationship: :ADDED
        },
        stop_time_update: []
      }

      [tu] = decode_trip_update(update)

      assert tu ==
               TripUpdate.new(
                 trip_id: "trip",
                 route_id: "route",
                 direction_id: 1,
                 start_date: ~D[2017-12-20],
                 start_time: "26:15:09",
                 schedule_relationship: :ADDED
               )
    end

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
