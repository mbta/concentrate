defmodule Concentrate.Parser.StopPredictionStatus do
  @moduledoc """
  Server which stores a set of route_id, direction_id, and stop_ids which is used to
  filter out StopTimeUpdate structs for that combination.
  """

  @spec flagged_stops_on_route(binary() | integer(), 0 | 1) :: nil | MapSet.t()
  def flagged_stops_on_route(route_id, direction_id)
      when not is_nil(route_id) and direction_id in [0, 1] do
    if route_id != nil and direction_id != nil do
      # TEMP: temporary test data
      MapSet.new([123])
    else
      nil
    end
  end

  def flagged_stops_on_route(_, _), do: nil
end
