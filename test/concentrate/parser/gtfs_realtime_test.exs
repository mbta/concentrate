defmodule Concentrate.Parser.GTFSRealtimeTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.TestHelpers
  import Concentrate.Parser.GTFSRealtime
  alias Concentrate.{VehiclePosition, TripUpdate, StopTimeUpdate, Alert}
  alias Concentrate.Parser.GTFSRealtime.Options

  describe "parse/1" do
    test "parsing a vehiclepositions.pb file returns only VehiclePosition or TripUpdate structs" do
      binary = File.read!(fixture_path("vehiclepositions.pb"))
      parsed = parse(binary, [])
      assert [_ | _] = parsed

      for vp <- parsed do
        assert vp.__struct__ in [VehiclePosition, TripUpdate]
      end
    end

    test "parsing a tripupdates.pb file returns only StopTimeUpdate or TripUpdate structs" do
      binary = File.read!(fixture_path("tripupdates.pb"))
      parsed = parse(binary, [])
      assert [_ | _] = parsed

      for update <- parsed do
        assert update.__struct__ in [StopTimeUpdate, TripUpdate]
      end
    end

    test "parsing an alerts.pb returns only alerts" do
      binary = File.read!(fixture_path("alerts.pb"))
      parsed = parse(binary, [])
      assert [_ | _] = parsed

      for alert <- parsed do
        assert alert.__struct__ == Alert
      end
    end

    test "options are parsed" do
      binary = File.read!(fixture_path("tripupdates.pb"))
      now = :os.system_time(:seconds)
      assert parse(binary, max_future_time: -now) == []
      assert parse(binary, routes: []) == []
      with_excluded = parse(binary, excluded_routes: ["Green-D"])
      refute with_excluded == []
      refute with_excluded == parse(binary, [])
    end
  end

  describe "decode_trip_update/2" do
    test "parses the trip descriptor" do
      update = %{
        trip: %{
          trip_id: "trip",
          route_id: "route",
          direction_id: 1,
          start_date: "20171220",
          start_time: "26:15:09",
          schedule_relationship: :ADDED
        },
        stop_time_update: [%{}]
      }

      [tu, _] = decode_trip_update(update, %Options{})

      assert tu ==
               TripUpdate.new(
                 trip_id: "trip",
                 route_id: "route",
                 direction_id: 1,
                 start_date: {2017, 12, 20},
                 start_time: "26:15:09",
                 schedule_relationship: :ADDED
               )
    end

    test "can handle nil times as well as nil events" do
      update = %{
        trip: %{},
        stop_time_update: [
          %{
            arrival: nil,
            departure: %{}
          }
        ]
      }

      [_tu, stop_update] = decode_trip_update(update, %Options{})
      refute StopTimeUpdate.arrival_time(stop_update)
      refute StopTimeUpdate.departure_time(stop_update)
    end

    test "can handle missing schedule_relationship" do
      update = %{
        trip: %{},
        stop_time_update: [%{}]
      }

      [tu, stu] = decode_trip_update(update, %Options{})
      assert TripUpdate.schedule_relationship(tu) == :SCHEDULED
      assert StopTimeUpdate.schedule_relationship(stu) == :SCHEDULED
    end

    test "does not include trip or stop update if we're ignoring the route" do
      update = %{
        trip: %{route_id: "ignored"},
        stop_time_update: [
          %{
            departure: %{time: 1}
          }
        ]
      }

      assert [] = decode_trip_update(update, %Options{routes: {:ok, ["keeping"]}})
    end

    test "includes trip/stop update if we're keeping the route" do
      update = %{
        trip: %{route_id: "keeping"},
        stop_time_update: [
          %{
            departure: %{time: 1}
          }
        ]
      }

      assert [_, _] = decode_trip_update(update, %Options{routes: {:ok, ["keeping"]}})
    end

    test "does not include trip or stop update if we're not excluding the route" do
      update = %{
        trip: %{route_id: "ignored"},
        stop_time_update: [
          %{
            departure: %{time: 1}
          }
        ]
      }

      assert [] = decode_trip_update(update, %Options{excluded_routes: {:ok, ["ignored"]}})
    end

    test "includes trip or stop update if we're not excluding the route" do
      update = %{
        trip: %{route_id: "keeping"},
        stop_time_update: [
          %{
            departure: %{time: 1}
          }
        ]
      }

      assert [_, _] = decode_trip_update(update, %Options{excluded_routes: {:ok, ["ignored"]}})
    end

    test "only includes trip/stop update if it's under max_time" do
      update = %{
        trip: %{},
        stop_time_update: [
          %{
            departure: %{time: 2}
          }
        ]
      }

      assert [] = decode_trip_update(update, %Options{max_time: 1})
      assert [_, _] = decode_trip_update(update, %Options{max_time: 2})
    end

    test "keeps the whole trip even if later updates are later than the time" do
      update = %{
        trip: %{},
        stop_time_update: [
          %{
            arrival: %{time: 1}
          },
          %{
            departure: %{time: 2}
          }
        ]
      }

      assert [_, _, _] = decode_trip_update(update, %Options{max_time: 1})
    end

    test "keeps the trip even without stop time updates" do
      update = %{
        trip: %{},
        stop_time_update: []
      }

      assert [_] = decode_trip_update(update, %Options{})
    end

    test "ignores the trip when we're excluding the route even without stop time updates" do
      update = %{
        trip: %{route_id: "ignored"},
        stop_time_update: []
      }

      assert [] = decode_trip_update(update, %Options{routes: {:ok, ["keeping"]}})
    end
  end

  describe "decode_vehicle/2" do
    test "does not include trip or vehicle if we're ignoring the route" do
      position = %{
        trip: %{route_id: "ignoring"},
        vehicle: %{},
        position: %{latitude: 1, longitude: 1}
      }

      assert [] = decode_vehicle(position, %Options{routes: {:ok, ["keeping"]}})
    end

    test "includes trip/vehicle if we're keeping the route" do
      position = %{
        trip: %{route_id: "keeping"},
        vehicle: %{},
        position: %{latitude: 1, longitude: 1}
      }

      assert [_, _] = decode_vehicle(position, %Options{routes: {:ok, ["keeping"]}})
    end
  end
end
