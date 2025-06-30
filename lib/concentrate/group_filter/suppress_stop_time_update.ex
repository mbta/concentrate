defmodule Concentrate.GroupFilter.SuppressStopTimeUpdate do
  @moduledoc """
  Filters out StopTimeUpdates if stop on route and direction is currently flagged to suppress predictions.
  """
  @behaviour Concentrate.GroupFilter
  alias Concentrate.GTFS.Stops
  alias Concentrate.{StopTimeUpdate, TripDescriptor}
  require Logger

  @impl Concentrate.GroupFilter
  def filter(
        trip_group,
        stop_prediction_status_module \\ Concentrate.Filter.Suppress.StopPredictionStatus
      )

  def filter({td, vps, stus}, module) do
    suppressed_terminals =
      module.terminals_suppressed(TripDescriptor.route_id(td), TripDescriptor.direction_id(td))

    suppressed_stops =
      module.suppressed_stops_on_route(
        TripDescriptor.route_id(td),
        TripDescriptor.direction_id(td)
      )

    stus =
      stus
      |> perform_terminal_suppression(td, suppressed_terminals)
      |> perform_stop_suppression(td, suppressed_stops)

    {td, vps, stus}
  end

  def filter(other, _), do: other

  defp perform_terminal_suppression(stus, td, suppressed_terminals) do
    first_stu = List.first(stus)

    if TripDescriptor.update_type(td) in ["at_terminal", "reverse_trip"] && first_stu &&
         stop_id_suppressed?(suppressed_terminals, StopTimeUpdate.stop_id(first_stu)) do
      Logger.info(
        "event=terminal_predictions_suppression route_id=#{TripDescriptor.route_id(td)} direction_id=#{TripDescriptor.direction_id(td)} have been suppressed based on Screenplay API trigger"
      )

      []
    else
      stus
    end
  end

  defp perform_stop_suppression(stus, td, suppressed_stops) do
    {suppressed_stus, unsuppressed_stus} =
      Enum.split_with(stus, fn stu ->
        stop_id_suppressed?(
          suppressed_stops,
          StopTimeUpdate.stop_id(stu)
        )
      end)

    log_suppressed_stus(
      suppressed_stus,
      TripDescriptor.route_id(td),
      TripDescriptor.direction_id(td)
    )

    unsuppressed_stus
  end

  defp stop_id_suppressed?(suppressed_stops, stop_id) do
    case Stops.parent_station_id(stop_id) do
      "place-jfk" -> MapSet.member?(suppressed_stops, stop_id)
      parent_station_id -> MapSet.member?(suppressed_stops, parent_station_id)
    end
  end

  defp log_suppressed_stus(stus, route_id, direction_id) do
    Enum.each(stus, fn stu ->
      stop_id = StopTimeUpdate.stop_id(stu)

      Logger.info(
        "Predictions for stop_id=\"#{stop_id}\" route_id=#{route_id} direction_id=#{direction_id} have been suppressed based on Screenplay API trigger"
      )
    end)
  end
end
