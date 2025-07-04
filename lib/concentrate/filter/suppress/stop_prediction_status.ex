defmodule Concentrate.Filter.Suppress.StopPredictionStatus do
  @moduledoc """
  Server which stores a set of suppression_type, route_id, direction_id, and stop_ids which is used to
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
  def handle_events([event], _from, state) do
    event
    |> store_new_state()
    |> log_unsuppressed_stops()

    {:noreply, [], state, :hibernate}
  end

  defp store_new_state(new_state) do
    currently_suppressed_stops = :ets.tab2list(@table) |> Keyword.get(:entries, [])
    :ets.delete_all_objects(@table)
    :ets.insert(@table, {:entries, new_state})

    Enum.split_with(currently_suppressed_stops, fn entry ->
      MapSet.member?(MapSet.new(new_state), entry)
    end)
  end

  defp log_unsuppressed_stops({_, []}), do: :ok

  defp log_unsuppressed_stops({_unchanged_entries, changed_entries}) do
    Enum.each(changed_entries, fn %{
                                    route_id: route_id,
                                    direction_id: direction_id,
                                    stop_id: stop_id,
                                    suppression_type: suppression_type
                                  } ->
      Logger.info(
        "event=clear_screenplay_prediction_suppression stop_id=#{stop_id} route_id=#{route_id} direction_id=#{direction_id} suppression_type=#{suppression_type}"
      )
    end)
  end

  @spec suppressed_stops_on_route(binary() | integer(), 0 | 1) :: MapSet.t()
  def suppressed_stops_on_route(route_id, direction_id)
      when not is_nil(route_id) and direction_id in [0, 1] do
    @table
    |> :ets.tab2list()
    |> Keyword.get(:entries, [])
    |> Enum.filter(
      &(stop_suppression?(&1) and &1.route_id == route_id and &1.direction_id == direction_id)
    )
    |> Enum.map(fn %{stop_id: s} -> s end)
    |> MapSet.new()
  end

  def suppressed_stops_on_route(_, _), do: MapSet.new()

  @spec terminals_suppressed(binary() | integer(), 0 | 1) :: MapSet.t()
  def terminals_suppressed(route_id, direction_id)
      when not is_nil(route_id) and direction_id in [0, 1] do
    @table
    |> :ets.tab2list()
    |> Keyword.get(:entries, [])
    |> Enum.filter(
      &(terminal_suppression?(&1) and &1.route_id == route_id and &1.direction_id == direction_id)
    )
    |> Enum.map(fn %{stop_id: s} -> s end)
    |> MapSet.new()
  end

  def terminals_suppressed(_, _), do: MapSet.new()

  defp stop_suppression?(%{suppression_type: "stop"}), do: true
  defp stop_suppression?(_), do: false
  defp terminal_suppression?(%{suppression_type: "terminal"}), do: true
  defp terminal_suppression?(_), do: false
end
