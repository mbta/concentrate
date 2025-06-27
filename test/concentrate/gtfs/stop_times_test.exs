defmodule Concentrate.GTFS.StopTimesTest do
  @moduledoc false
  use ExUnit.Case
  alias Concentrate.GTFS.StopTimes

  @agency """
  agency_id,agency_name,agency_url,agency_timezone,agency_lang,agency_phone
  1,MBTA,http://www.mbta.com,America/New_York,EN,617-222-3200
  """

  @routes """
  route_id,agency_id,route_short_name,route_long_name,route_desc,route_type,route_url,route_color,route_text_color,route_sort_order
  CR-Middleborough,1,,Middleborough/Lakeville Line,Commuter Rail,2,https://www.mbta.com/schedules/CR-Middleborough,80276C,FFFFFF,20009
  CR-Worcester,1,,Framingham/Worcester Line,Commuter Rail,2,https://www.mbta.com/schedules/CR-Worcester,80276C,FFFFFF,20003
  """

  @trips """
  route_id,service_id,trip_id,trip_headsign,trip_short_name,direction_id,block_id,shape_id,wheelchair_accessible,bikes_allowed
  CR-Middleborough,SPRING2022-SOUTHSUN-Sunday-1-S8f,CR-524518-2019,Middleborough/Lakeville,2019,0,,9800002,1,1
  CR-Worcester,SPRING2022-SOUTHSUN-Sunday-1-Sb4,CR-524522-2502,South Station,2502,1,,9850001,1,1
  """

  @stop_times """
  trip_id,arrival_time,departure_time,stop_id,stop_sequence,stop_headsign,pickup_type,drop_off_type,timepoint,continuous_pickup,continuous_drop_off
  CR-524518-2019,20:25:00,20:25:00,NEC-2287,0,,0,1,1,,
  CR-524518-2019,20:31:00,20:31:00,MM-0023-S,10,,3,3,1,,
  CR-524518-2019,20:38:00,20:38:00,MM-0079-S,20,,3,3,1,,
  CR-524522-2502,7:10:00,7:10:00,WML-0442-CS,0,,0,1,1,,
  CR-524522-2502,7:23:00,7:23:00,WML-0364,10,,0,0,1,,
  CR-524522-2502,7:27:00,7:27:00,WML-0340,20,,0,0,1,,
  """

  defp supervised(_) do
    start_supervised(StopTimes)

    event = [
      {"agency.txt", @agency},
      {"routes.txt", @routes},
      {"trips.txt", @trips},
      {"stop_times.txt", @stop_times}
    ]

    StopTimes.handle_events([event], :ignored, :ignored)
    :ok
  end

  describe "arrival_departure/3" do
    setup :supervised

    test "returns scheduled arrival/departure times for a stop time with a reference date" do
      assert StopTimes.arrival_departure("CR-524518-2019", 10, {2022, 6, 12}) ==
               {1_655_080_260, 1_655_080_260}

      assert StopTimes.arrival_departure("CR-524518-2019", 10, {2022, 6, 19}) ==
               {1_655_685_060, 1_655_685_060}

      assert StopTimes.arrival_departure("CR-524522-2502", 0, {2022, 6, 19}) ==
               {1_655_637_000, 1_655_637_000}
    end

    test "returns :unknown for unknown trips or stop sequences" do
      assert StopTimes.arrival_departure("CR-524518-0000", 10, {2022, 6, 19}) == :unknown
      assert StopTimes.arrival_departure("CR-524518-2019", 30, {2022, 6, 19}) == :unknown
    end
  end

  describe "pick_up_drop_off/2" do
    setup :supervised

    test "returns pick-up/drop-off booleans for a stop time" do
      assert StopTimes.pick_up_drop_off("CR-524522-2502", 0) == {true, false}
    end

    test "returns true for all pick-up/drop-off types other than 1" do
      assert StopTimes.pick_up_drop_off("CR-524518-2019", 10) == {true, true}
    end

    test "returns :unknown for unknown trips or stop sequences" do
      assert StopTimes.pick_up_drop_off("CR-524518-0000", 10) == :unknown
      assert StopTimes.pick_up_drop_off("CR-524518-2019", 30) == :unknown
    end
  end

  describe "stop_id/2" do
    setup :supervised

    test "returns the stop ID for a stop time" do
      assert StopTimes.stop_id("CR-524522-2502", 0) == "WML-0442-CS"
      assert StopTimes.stop_id("CR-524518-2019", 20) == "MM-0079-S"
    end

    test "returns :unknown for unknown trips or stop sequences" do
      assert StopTimes.stop_id("CR-524518-0000", 10) == :unknown
      assert StopTimes.stop_id("CR-524518-2019", 30) == :unknown
    end
  end

  describe "missing ETS table" do
    test "all functions return :unknown" do
      assert StopTimes.arrival_departure("CR-524518-2019", 10, {2022, 6, 19}) == :unknown
      assert StopTimes.pick_up_drop_off("CR-524518-2019", 10) == :unknown
      assert StopTimes.stop_id("CR-524518-2019", 10) == :unknown
    end
  end
end
