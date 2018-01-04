defmodule Concentrate.Filter.Alert.CancelledTrips do
  @moduledoc """
  Maintains a table of the currently cancelled trips.
  """
  use GenStage
  require Logger
  alias Concentrate.{Alert, Alert.InformedEntity}
  import Calendar.ISO, only: [from_unix: 2]

  @table __MODULE__
  @empty_value []

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def trip_cancelled?(trip_id, {_, _, _} = date) when is_binary(trip_id) do
    key = {trip_id, date}
    :ets.member(@table, key)
  end

  def trip_cancelled?(trip_id, unix) when is_binary(trip_id) do
    select =
      {
        {{trip_id, :_}, :"$1", :"$2"},
        [
          {:"=<", :"$1", unix},
          {:"=<", unix, :"$2"}
        ],
        [@empty_value]
      }

    :ets.select(@table, [select]) != []
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
          trip_id = InformedEntity.trip_id(entity),
          not is_nil(trip_id),
          {start, stop} <- Alert.active_period(alert),
          date_time <- [start, stop] do
        {:ok, date, _, _} = from_unix(date_time, :second)
        {{trip_id, date}, start, stop}
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
end
