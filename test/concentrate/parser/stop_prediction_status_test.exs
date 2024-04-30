defmodule Concentrate.Parser.StopPredictionStatusTest do
  @moduledoc false
  use ExUnit.Case
  alias Concentrate.Parser.StopPredictionStatus
  alias Concentrate.TripDescriptor

  describe "flagged_stops_on_route" do
    test "retuns a MapSet of stop_ids relevant to the route_id and direction_id provided" do
      assert MapSet.new([123]) ==
               StopPredictionStatus.flagged_stops_on_route(%TripDescriptor{
                 route_id: "Red",
                 direction_id: 0
               })
    end

    test "returns nil if missing stop_id or direction_id" do
      assert nil ==
               StopPredictionStatus.flagged_stops_on_route(%TripDescriptor{
                 route_id: nil,
                 direction_id: 1
               })

      assert nil ==
               StopPredictionStatus.flagged_stops_on_route(%TripDescriptor{
                 route_id: "Red",
                 direction_id: nil
               })
    end
  end
end
