defmodule Concentrate.Filter.Alert.Shuttles do
  @moduledoc """
  Maintains a table of the current shuttles.
  """
  use GenStage
  require Logger
  alias Concentrate.Filter.Alert.TimeTable
  alias Concentrate.{Alert, Alert.InformedEntity}

  @table __MODULE__
  @empty_value []

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def route_shuttling?(route_id, direction_id, date_or_timestamp) when is_binary(route_id) do
    date_overlaps?({:route, route_id, direction_id}, date_or_timestamp)
  end

  def stop_shuttling_on_route?(route_id, stop_id, date_or_timestamp)
      when is_binary(route_id) and is_binary(stop_id) do
    date_overlaps?({:route_stop, route_id, stop_id}, date_or_timestamp)
  end

  defp date_overlaps?(key, date_or_timestamp) do
    TimeTable.date_overlaps(@table, key, date_or_timestamp, count: 1) != []
  end

  def init(opts) do
    TimeTable.new(@table)
    {:consumer, [], opts}
  end

  def handle_events(events, _from, state) do
    alerts = List.last(events)

    inserts =
      for alert <- alerts,
          Alert.effect(alert) == :DETOUR,
          entity <- Alert.informed_entity(alert),
          InformedEntity.route_type(entity) in [0, 1, 2],
          key <- cancellation_type(entity),
          {start, stop} <- Alert.active_period(alert) do
        {key, start, stop, @empty_value}
      end

    unless inserts == [] do
      TimeTable.update(@table, inserts)

      _ =
        Logger.info(fn ->
          "#{__MODULE__} updated: records=#{length(inserts)}"
        end)
    end

    {:noreply, [], state}
  end

  defp cancellation_type(entity) do
    stop_id = InformedEntity.stop_id(entity)
    route_id = InformedEntity.route_id(entity)

    if is_nil(stop_id) or is_nil(route_id) do
      []
    else
      route_stops = [
        {:route_stop, route_id, stop_id}
      ]

      routes =
        for direction_id <- direction_ids(InformedEntity.direction_id(entity)) do
          {:route, route_id, direction_id}
        end

      route_stops ++ routes
    end
  end

  defp direction_ids(nil), do: [0, 1, nil]
  defp direction_ids(value), do: [value]
end
