defmodule Concentrate.GroupFilter.RemoveUncertainStopTimesTest do
  use ExUnit.Case, async: true
  alias Concentrate.GroupFilter.RemoveUncertainStopTimeUpdates
  alias Concentrate.{StopTimeUpdate, TripDescriptor}

  @mid_trip 60
  @at_terminal 120
  @reverse_prediction 360

  describe "filter/2" do
    test "handles nil TripDescriptors" do
      group =
        {nil, [], [StopTimeUpdate.new(trip_id: "green_c_trip", uncertainty: @reverse_prediction)]}

      assert RemoveUncertainStopTimeUpdates.filter(group, %{
               "Red" => [
                 %{@at_terminal => [0, 1]},
                 %{@reverse_prediction => [0, 1]}
               ]
             }) == group
    end

    test "keeps terminal and reverse predictions for routes not specified" do
      group =
        {TripDescriptor.new(trip_id: "green_c_trip", route_id: "Green-C"), [],
         [StopTimeUpdate.new(trip_id: "green_c_trip", uncertainty: @reverse_prediction)]}

      assert RemoveUncertainStopTimeUpdates.filter(group, %{}) == group
    end

    test "keeps terminal and reverse predictions for specified routes for uncertainties and directions not specified" do
      group =
        {TripDescriptor.new(trip_id: "red_trip", route_id: "Red"), [],
         [StopTimeUpdate.new(trip_id: "red_trip", uncertainty: @mid_trip)]}

      assert RemoveUncertainStopTimeUpdates.filter(group, %{
               "Red" => %{@at_terminal => [0, 1], @reverse_prediction => [0, 1]}
             }) == group

      group =
        {TripDescriptor.new(trip_id: "red_trip", route_id: "Red", direction_id: 0), [],
         [StopTimeUpdate.new(trip_id: "red_trip", uncertainty: @reverse_prediction)]}

      assert RemoveUncertainStopTimeUpdates.filter(group, %{
               "Red" => %{@at_terminal => [1], @reverse_prediction => [1]}
             }) == group
    end

    test "removes uncertain predictions for specified routes" do
      group =
        {TripDescriptor.new(trip_id: "red_trip", route_id: "Red", direction_id: 0), [],
         [
           StopTimeUpdate.new(trip_id: "red_trip", uncertainty: @at_terminal),
           StopTimeUpdate.new(trip_id: "red_trip", uncertainty: @reverse_prediction)
         ]}

      assert RemoveUncertainStopTimeUpdates.filter(group, %{
               "Red" => %{@at_terminal => [0, 1], @reverse_prediction => [0, 1]}
             }) ==
               {TripDescriptor.new(trip_id: "red_trip", route_id: "Red", direction_id: 0), [], []}
    end
  end
end
