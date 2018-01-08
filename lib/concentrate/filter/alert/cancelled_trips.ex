defmodule Concentrate.Filter.Alert.CancelledTrips do
  @moduledoc """
  Maintains a table of the currently cancelled trips.
  """
  use GenStage
  require Logger
  alias Concentrate.{Alert, Alert.InformedEntity}

  @table __MODULE__
  @empty_value []
  @epoch_seconds :calendar.datetime_to_gregorian_seconds({{1970, 1, 1}, {0, 0, 0}})
  @one_day_minus_one 86_399

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def route_cancelled?(route_id, date_or_timestamp) when is_binary(route_id) do
    date_overlaps?({:route, route_id}, date_or_timestamp)
  end

  def trip_cancelled?(trip_id, date_or_timestamp) when is_binary(trip_id) do
    date_overlaps?({:trip, trip_id}, date_or_timestamp)
  end

  defp date_overlaps?(key, {_, _, _} = date) do
    start_of_day_unix =
      :calendar.datetime_to_gregorian_seconds({date, {0, 0, 0}}) - @epoch_seconds

    end_of_day_unix = start_of_day_unix + @one_day_minus_one
    date_overlaps?(key, start_of_day_unix, end_of_day_unix)
  end

  defp date_overlaps?(key, unix) when is_integer(unix) do
    date_overlaps?(key, unix, unix)
  end

  defp date_overlaps?(trip_id, start, stop) do
    select =
      {
        {trip_id, :"$1", :"$2"},
        [
          {:"=<", :"$1", stop},
          {:"=<", start, :"$2"}
        ],
        [@empty_value]
      }

    :ets.select(@table, [select], 1) != :"$end_of_table"
  end

  def init(opts) do
    :ets.new(@table, [:named_table, :public, :bag])
    {:consumer, [], opts}
  end

  def handle_events(events, _from, state) do
    alerts = List.last(events)

    inserts =
      for alert <- alerts,
          Alert.effect(alert) == :NO_SERVICE,
          entity <- Alert.informed_entity(alert),
          is_nil(InformedEntity.stop_id(entity)),
          key <- cancellation_type(entity),
          {start, stop} <- Alert.active_period(alert) do
        {key, start, stop}
      end

    unless inserts == [] do
      :ets.delete_all_objects(@table)
      :ets.insert(@table, inserts)

      _ =
        Logger.info(fn ->
          "#{__MODULE__} updated: #{length(inserts)} records"
        end)
    end

    {:noreply, [], state}
  end

  defp cancellation_type(entity) do
    cond do
      is_binary(trip_id = InformedEntity.trip_id(entity)) ->
        [{:trip, trip_id}]

      is_binary(route_id = InformedEntity.route_id(entity)) ->
        [{:route, route_id}]

      true ->
        []
    end
  end
end
