defmodule Concentrate.Parser.StopPredictionStatusTest do
  @moduledoc false
  use ExUnit.Case
  alias Concentrate.Parser.StopPredictionStatus

  describe "flagged_stops_on_route/2" do
    test "retuns a MapSet of stop_ids relevant to the route_id and direction_id provided" do
      assert MapSet.new([123]) == StopPredictionStatus.flagged_stops_on_route("Red", 0)
    end

    test "returns nil if missing stop_id or direction_id" do
      assert nil == StopPredictionStatus.flagged_stops_on_route(nil, 1)

      assert nil == StopPredictionStatus.flagged_stops_on_route("Red", nil)
    end
  end
end
