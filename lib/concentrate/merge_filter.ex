defmodule Concentrate.MergeFilter do
  @moduledoc """
  ProducerConsumer which merges the data given to it, filters, and outputs the result.

  * After receiving an event, schedule a timeout for 1s
  * When the timeout happens, merge and filter the current state
  """
  use GenStage
  require Logger
  alias Concentrate.Encoder.GTFSRealtimeHelpers
  alias Concentrate.{FeedUpdate, Filter, TripDescriptor}
  alias Concentrate.Merge.Table

  @start_link_opts [:name]
  # allow sources some time to load
  @initial_timeout 5_000

  defstruct timeout: 1_000,
            timer: nil,
            table: Table.new(),
            demand: %{},
            filters: [],
            group_filters: []

  def start_link(opts \\ []) do
    start_link_opts = Keyword.take(opts, @start_link_opts)
    opts = Keyword.drop(opts, @start_link_opts)
    GenStage.start_link(__MODULE__, opts, start_link_opts)
  end

  @impl GenStage
  def init(opts) do
    filters = build_filters(Keyword.get(opts, :filters, []))
    group_filters = build_group_filters(Keyword.get(opts, :group_filters, []))
    state = %__MODULE__{filters: filters, group_filters: group_filters}

    state =
      case Keyword.fetch(opts, :timeout) do
        {:ok, timeout} -> %{state | timeout: timeout}
        _ -> state
      end

    initial_timeout = Keyword.get(opts, :initial_timeout, @initial_timeout)
    opts = Keyword.take(opts, [:subscribe_to, :dispatcher])
    opts = Keyword.put_new(opts, :dispatcher, GenStage.BroadcastDispatcher)
    state = %{state | timer: Process.send_after(self(), :timeout, initial_timeout)}
    {:producer_consumer, state, opts}
  end

  @impl GenStage
  def handle_subscribe(_, _, _, state) do
    {:automatic, state}
  end

  @impl GenStage
  def handle_cancel(_reason, from, state) do
    state = %{
      state
      | table: Table.remove(state.table, from)
    }

    {:noreply, [], state}
  end

  @impl GenStage
  def handle_events(events, from, state) do
    state =
      Enum.reduce(events, state, fn event, state ->
        key = FeedUpdate.url(event) || from
        updates = FeedUpdate.updates(event)

        table =
          if FeedUpdate.partial?(event) do
            Table.partial_update(state.table, key, updates)
          else
            Table.update(state.table, key, updates)
          end

        %{
          state
          | table: table
        }
      end)

    state =
      if state.timer do
        state
      else
        %{state | timer: Process.send_after(self(), :timeout, state.timeout)}
      end

    {:noreply, [], state}
  end

  @impl GenStage
  def handle_info(:timeout, state) do
    timestamp = System.system_time(:microsecond) / 1_000_000
    {time, merged} = :timer.tc(&Table.items/1, [state.table])

    _ =
      Logger.debug(fn ->
        "#{__MODULE__} merge time=#{time / 1_000}"
      end)

    {time, filtered} = :timer.tc(&Filter.run/2, [merged, state.filters])

    _ =
      Logger.debug(fn ->
        "#{__MODULE__} filter time=#{time / 1_000}"
      end)

    {time, grouped} = :timer.tc(&GTFSRealtimeHelpers.group/1, [filtered])

    _ =
      Logger.debug(fn ->
        "#{__MODULE__} group time=#{time / 1_000}"
      end)

    {time, group_filtered} = :timer.tc(&group_filter/2, [grouped, state.group_filters])

    _ =
      Logger.debug(fn ->
        "#{__MODULE__} group_filter time=#{time / 1_000}"
      end)

    update =
      FeedUpdate.new(
        timestamp: timestamp,
        updates: group_filtered
      )

    state = %{state | timer: nil}
    {:noreply, [update], state}
  end

  def handle_info(msg, state) do
    _ =
      Logger.warn(fn ->
        "unknown message to #{__MODULE__} #{inspect(self())}: #{inspect(msg)}"
      end)

    {:noreply, [], state}
  end

  defp parse_filter({filter, _opts}), do: filter
  defp parse_filter(filter), do: filter

  defp build_filters(filters) do
    Enum.map(filters, &parse_filter/1)
  end

  defp build_group_filters(filters) do
    for filter <- filters do
      fun =
        case filter do
          filter when is_atom(filter) ->
            &filter.filter/1

          {filter, _options} when is_atom(filter) ->
            &filter.filter/1

          filter when is_function(filter, 1) ->
            filter
        end

      flat_mapper(fun)
    end
  end

  defp flat_mapper(fun) do
    fn value ->
      case fun.(value) do
        {%TripDescriptor{} = td, [], []} ->
          flat_map_empty_trip_update(td)

        {nil, _, _} ->
          []

        other ->
          [other]
      end
    end
  end

  defp flat_map_empty_trip_update(td) do
    # allow CANCELED TripUpdates to have no vehicle or stops
    if TripDescriptor.schedule_relationship(td) == :CANCELED do
      [{td, [], []}]
    else
      []
    end
  end

  defp group_filter(groups, filters) do
    Enum.reduce(filters, groups, fn filter, groups ->
      Enum.flat_map(groups, filter)
    end)
  end
end
