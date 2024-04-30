defmodule Concentrate.GroupFilter.SuppressStopTimeUpdate do
  @moduledoc """
  Filters out StopTimeUpdates if stop on route and direction is currently flagged to suppress predictions.
  """
  @behaviour Concentrate.GroupFilter
  alias Concentrate.Parser.StopPredictionStatus
  alias Concentrate.StopTimeUpdate
  alias Concentrate.TripDescriptor
  require Logger

  @impl Concentrate.GroupFilter
  def filter({td, vps, stus}) do
    case StopPredictionStatus.flagged_stops_on_route(td) do
      nil ->
        {td, vps, stus}

      suppressed_stops ->
        route_id = TripDescriptor.route_id(td)
        direction_id = TripDescriptor.direction_id(td)

        unsuppressed_stus =
          Enum.reject(stus, fn stu ->
            stop_id_suppressed?(
              suppressed_stops,
              StopTimeUpdate.stop_id(stu),
              route_id,
              direction_id
            )
          end)

        {td, vps, unsuppressed_stus}
    end
  end

  def filter(other), do: other

  defp stop_id_suppressed?(suppressed_stops, stop_id, route_id, direction_id) do
    if MapSet.member?(suppressed_stops, stop_id) do
      Logger.info(fn ->
        "Predictions for stop_id=#{stop_id} route_id=#{route_id} direction_id=#{direction_id} have been suppressed based on RTS feed trigger"
      end)

      true
    else
      false
    end
  end
end
