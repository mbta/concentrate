defmodule Concentrate.Filter.Alert.ClosedStops do
  @moduledoc """
  Maintains a table of the currently closed stops.
  """
  use GenStage
  require Logger
  alias Concentrate.{Alert, Alert.InformedEntity}

  @table __MODULE__

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec stop_closed_for(String.t(), integer) :: [Alert.InformedEntity.t()]
  def stop_closed_for(stop_id, unix) when is_binary(stop_id) do
    matcher = {
      {stop_id, :"$1", :"$2", :"$3"},
      [
        # DateTime is between the start/end dates
        {:"=<", :"$1", unix},
        {:"=<", unix, :"$2"}
      ],
      [:"$3"]
    }

    :ets.select(@table, [matcher])
  rescue
    ArgumentError -> []
  end

  def init(opts) do
    :ets.new(@table, [:named_table, :public, :bag])
    {:consumer, [], opts}
  end

  def handle_events(events, _from, state) do
    alerts = List.last(events)

    inserts =
      for alert <- alerts,
          entity <- closed_stop_entities(alert),
          stop_id = InformedEntity.stop_id(entity),
          {start, stop} <- Alert.active_period(alert) do
        {stop_id, start, stop, entity}
      end

    unless inserts == [] do
      :ets.delete_all_objects(@table)
      :ets.insert(@table, inserts)

      _ =
        Logger.info(fn ->
          "#{__MODULE__} updated: records=#{length(inserts)}"
        end)
    end

    {:noreply, [], state}
  end

  defp closed_stop_entities(alert) do
    cond do
      Alert.effect(alert) == :NO_SERVICE ->
        for entity <- Alert.informed_entity(alert), not is_nil(InformedEntity.stop_id(entity)) do
          entity
        end

      Alert.effect(alert) == :DETOUR ->
        for entity <- Alert.informed_entity(alert),
            not is_nil(InformedEntity.stop_id(entity)),
            InformedEntity.route_type(entity) in [3, 4] do
          entity
        end

      true ->
        []
    end
  end
end
