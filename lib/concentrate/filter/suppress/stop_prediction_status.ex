defmodule Concentrate.Filter.Suppress.StopPredictionStatus do
  @moduledoc """
  Server which stores a set of route_id, direction_id, and stop_ids which is used to
  filter out StopTimeUpdate structs for that combination.
  """
  use GenStage
  require Logger

  @table __MODULE__

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenStage
  def init(opts) do
    _ = :ets.new(@table, [:named_table, :public, :set])
    {:consumer, [], opts}
  end

  @impl GenStage
  def handle_events(events, _from, state) do
    events
    |> store_new_state()
    |> log_unsuppressed_stops()

    {:noreply, [], state, :hibernate}
  end

  defp store_new_state([:empty]), do: store_new_state([])

  defp store_new_state(events) do
    currently_suppressed_stops = :ets.tab2list(@table) |> Keyword.get(:entries, [])
    :ets.delete_all_objects(@table)
    :ets.insert(@table, {:entries, events})

    Enum.split_with(currently_suppressed_stops, fn event ->
      MapSet.member?(MapSet.new(events), event)
    end)
  end

  defp log_unsuppressed_stops({_, []}), do: :ok

  defp log_unsuppressed_stops({_unchanged_entries, changed_entries}) do
    Enum.each(changed_entries, fn %{
                                    route_id: route_id,
                                    direction_id: direction_id,
                                    stop_id: stop_id
                                  } ->
      Logger.info(
        "Cleared prediction suppression for stop_id=#{stop_id} route_id=#{route_id} direction_id=#{direction_id} based on RTS feed"
      )
    end)
  end

  @spec flagged_stops_on_route(binary() | integer(), 0 | 1) :: nil | MapSet.t()
  def flagged_stops_on_route(route_id, direction_id)
      when not is_nil(route_id) and direction_id in [0, 1] do
    if route_id != nil and direction_id != nil do
      @table
      |> :ets.tab2list()
      |> Keyword.get(:entries, [])
      |> Enum.filter(fn %{route_id: r, direction_id: d} ->
        r == route_id and d == direction_id
      end)
      |> Enum.map(fn %{stop_id: s} -> s end)
      |> MapSet.new()
    else
      nil
    end
  end

  def flagged_stops_on_route(_, _), do: nil
end
