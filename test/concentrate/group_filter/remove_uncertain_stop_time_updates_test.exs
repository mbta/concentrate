defmodule Concentrate.GroupFilter.RemoveUncertainStopTimesTest do
  use ExUnit.Case, async: true
  alias Concentrate.GroupFilter.RemoveUncertainStopTimeUpdates
  alias Concentrate.TripDescriptor
  alias Concentrate.StopTimeUpdate

  @mid_trip 60
  @at_terminal 120
  @reverse_prediction 360

  describe "filter/2" do
    test "keeps terminal and reverse predictions for routes not specified" do
      trip_update =
        {TripDescriptor.new(trip_id: "green_c_trip", route_id: "Green-C"), [],
         [StopTimeUpdate.new(trip_id: "green_c_trip", uncertainty: @reverse_prediction)]}

      assert RemoveUncertainStopTimeUpdates.filter(trip_update, %{}) == trip_update
    end

    test "keeps terminal and reverse predictions for specified routes for uncertainties not specified" do
      trip_update =
        {TripDescriptor.new(trip_id: "red_trip", route_id: "Red"), [],
         [StopTimeUpdate.new(trip_id: "red_trip", uncertainty: @mid_trip)]}

      assert RemoveUncertainStopTimeUpdates.filter(trip_update, %{
               "Red" => [@at_terminal, @reverse_prediction]
             }) == trip_update
    end

    test "removes uncertain predictions for specified routes" do
      trip_update =
        {TripDescriptor.new(trip_id: "red_trip", route_id: "Red"), [],
         [
           StopTimeUpdate.new(trip_id: "red_trip", uncertainty: @at_terminal),
           StopTimeUpdate.new(trip_id: "red_trip", uncertainty: @reverse_prediction)
         ]}

      assert RemoveUncertainStopTimeUpdates.filter(trip_update, %{
               "Red" => [@at_terminal, @reverse_prediction]
             }) ==
               {TripDescriptor.new(trip_id: "red_trip", route_id: "Red"), [], []}
    end
  end
end
