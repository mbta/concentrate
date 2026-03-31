defmodule Concentrate.GroupFilter.RemoveUncertainStopTimesTest do
  use ExUnit.Case, async: true
  alias Concentrate.Encoder.TripGroup
  alias Concentrate.GroupFilter.RemoveUncertainStopTimeUpdates
  alias Concentrate.{StopTimeUpdate, TripDescriptor}

  @mid_trip 60
  @at_terminal 120
  @reverse_prediction 360

  describe "filter/2" do
    test "handles nil TripDescriptors" do
      group =
        %TripGroup{
          td: nil,
          stus: [StopTimeUpdate.new(trip_id: "green_c_trip", uncertainty: @reverse_prediction)]
        }

      assert RemoveUncertainStopTimeUpdates.filter(group, %{
               "Red" => [
                 %{@at_terminal => [0, 1]},
                 %{@reverse_prediction => [0, 1]}
               ]
             }) == group
    end

    test "keeps terminal and reverse predictions for routes not specified" do
      group =
        %TripGroup{
          td: TripDescriptor.new(trip_id: "green_c_trip", route_id: "Green-C"),
          stus: [StopTimeUpdate.new(trip_id: "green_c_trip", uncertainty: @reverse_prediction)]
        }

      assert RemoveUncertainStopTimeUpdates.filter(group, %{}) == group
    end

    test "keeps terminal and reverse predictions for specified routes for uncertainties and directions not specified" do
      group =
        %TripGroup{
          td: TripDescriptor.new(trip_id: "red_trip", route_id: "Red"),
          stus: [StopTimeUpdate.new(trip_id: "red_trip", uncertainty: @mid_trip)]
        }

      assert RemoveUncertainStopTimeUpdates.filter(group, %{
               "Red" => %{@at_terminal => [0, 1], @reverse_prediction => [0, 1]}
             }) == group

      group =
        %TripGroup{
          td: TripDescriptor.new(trip_id: "red_trip", route_id: "Red", direction_id: 0),
          stus: [StopTimeUpdate.new(trip_id: "red_trip", uncertainty: @reverse_prediction)]
        }

      assert RemoveUncertainStopTimeUpdates.filter(group, %{
               "Red" => %{@at_terminal => [1], @reverse_prediction => [1]}
             }) == group
    end

    test "removes uncertain predictions for specified routes" do
      group =
        %TripGroup{
          td: TripDescriptor.new(trip_id: "red_trip", route_id: "Red", direction_id: 0),
          stus: [
            StopTimeUpdate.new(trip_id: "red_trip", uncertainty: @at_terminal),
            StopTimeUpdate.new(trip_id: "red_trip", uncertainty: @reverse_prediction)
          ]
        }

      assert RemoveUncertainStopTimeUpdates.filter(group, %{
               "Red" => %{@at_terminal => [0, 1], @reverse_prediction => [0, 1]}
             }) ==
               %TripGroup{
                 td: TripDescriptor.new(trip_id: "red_trip", route_id: "Red", direction_id: 0)
               }
    end
  end
end
