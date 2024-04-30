defmodule Concentrate.Parser.StopPredictionStatus do
  @moduledoc """
  Server which stores a set of route_id, direction_id, and stop_ids which is used to
  filter out StopTimeUpdate structs for that combination.
  """

  alias Concentrate.TripDescriptor

  @spec flagged_stops_on_route(TripDescriptor.t()) :: nil | MapSet.t()
  def flagged_stops_on_route(%TripDescriptor{} = td) do
    route_id = TripDescriptor.route_id(td)
    direction_id = TripDescriptor.direction_id(td)

    if route_id != nil and direction_id != nil do
      # TEMP: temporary test data
      MapSet.new([123])
    else
      nil
    end
  end

  def flagged_stops_on_route(_), do: nil
end
