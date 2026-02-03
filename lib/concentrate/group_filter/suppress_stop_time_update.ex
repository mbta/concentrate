defmodule Concentrate.GroupFilter.SuppressStopTimeUpdate do
  @moduledoc """
  Filters out StopTimeUpdates if stop on route and direction is currently flagged to suppress predictions.
  Stops can be flagged for prediction suppression in a couple of different ways:
  - Via the Screenplay API
  - Via an application-configurable time range
  """
  @behaviour Concentrate.GroupFilter
  alias Concentrate.GTFS.Stops
  alias Concentrate.{StopTimeUpdate, TripDescriptor}
  require Logger

  config_path = [:group_filters, __MODULE__, :terminal_suppression_by_time]

  @terminal_suppression_by_time Application.compile_env(:concentrate, config_path, %{})
  @time_zone Application.compile_env(:concentrate, :time_zone)

  @impl Concentrate.GroupFilter
  def filter(
        trip_group,
        stop_prediction_status_module \\ Concentrate.Filter.Suppress.StopPredictionStatus,
        now_fn \\ &now/0
      )

  def filter({td, vps, stus}, module, now_fn) do
    suppressed_terminals =
      module.terminals_suppressed(TripDescriptor.route_id(td), TripDescriptor.direction_id(td))

    suppressed_stops =
      module.suppressed_stops_on_route(
        TripDescriptor.route_id(td),
        TripDescriptor.direction_id(td)
      )

    {:ok, now} = now_fn.()

    stus =
      stus
      |> perform_terminal_suppression(td, suppressed_terminals)
      |> perform_stop_suppression(td, suppressed_stops)
      |> perform_terminal_suppression_by_time(td, now)

    {td, vps, stus}
  end

  def filter(other, _, _), do: other

  defp now do
    DateTime.now(@time_zone)
  end

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

  defp perform_terminal_suppression_by_time(stus, td, now) do
    first_stu = List.first(stus)

    if TripDescriptor.update_type(td) in ["at_terminal", "reverse_trip"] && first_stu &&
         terminal_suppressed_at_time?(StopTimeUpdate.stop_id(first_stu), now) do
      Logger.info(
        "event=terminal_predictions_suppression_by_time route_id=#{TripDescriptor.route_id(td)} direction_id=#{TripDescriptor.direction_id(td)} have been suppressed based on time range"
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

  defp terminal_suppressed_at_time?(stop_id, now) do
    day_of_week = now |> DateTime.to_date() |> Date.day_of_week()
    time = DateTime.to_time(now)

    parent_station_id = Stops.parent_station_id(stop_id)

    if Map.has_key?(@terminal_suppression_by_time, parent_station_id) do
      {start_time, end_time} = @terminal_suppression_by_time[parent_station_id][day_of_week]

      Time.after?(time, start_time) and Time.before?(time, end_time)
    else
      false
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
