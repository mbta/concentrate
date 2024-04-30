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
    route_id = TripDescriptor.route_id(td)
    direction_id = TripDescriptor.direction_id(td)

    case StopPredictionStatus.flagged_stops_on_route(route_id, direction_id) do
      nil ->
        {td, vps, stus}

      suppressed_stops ->
        {suppressed_stus, unsuppressed_stus} =
          Enum.split_with(stus, fn stu ->
            stop_id_suppressed?(
              suppressed_stops,
              StopTimeUpdate.stop_id(stu)
            )
          end)

        _ = log_suppressed_stus(suppressed_stus, route_id, direction_id)

        {td, vps, unsuppressed_stus}
    end
  end

  def filter(other), do: other

  defp stop_id_suppressed?(suppressed_stops, stop_id),
    do: MapSet.member?(suppressed_stops, stop_id)

  defp log_suppressed_stus(stus, route_id, direction_id) do
    Enum.map(stus, fn stu ->
      stop_id = StopTimeUpdate.stop_id(stu)

      Logger.info(fn ->
        "Predictions for stop_id=#{stop_id} route_id=#{route_id} direction_id=#{direction_id} have been suppressed based on RTS feed trigger"
      end)
    end)
  end
end
