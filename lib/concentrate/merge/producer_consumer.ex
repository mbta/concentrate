defmodule Concentrate.Merge.ProducerConsumer do
  @moduledoc """
  ProducerConsumer which merges the data given to it and outputs the merged data.
  """
  use GenStage
  require Logger
  alias Concentrate.Merge
  @start_link_opts [:name]

  def start_link(opts \\ []) do
    start_link_opts = Keyword.take(opts, @start_link_opts)
    opts = Keyword.drop(opts, @start_link_opts)
    GenStage.start_link(__MODULE__, opts, start_link_opts)
  end

  @impl GenStage
  def init(opts) do
    {timeout, opts} = Keyword.pop(opts, :timeout, 1_000)
    state = %{timeout: timeout, timer: nil, data: %{}}
    opts = Keyword.take(opts, [:subscribe_to])
    {:producer_consumer, state, opts}
  end

  @impl GenStage
  def handle_events(events, from, %{data: data} = state) do
    latest_data = List.last(events)
    state = put_in(state.data, Map.put(data, from, latest_data))

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
    {time, merged} =
      :timer.tc(fn ->
        state.data
        |> Stream.flat_map(fn {_from, data} -> data end)
        |> Merge.merge()
      end)

    Logger.debug(fn ->
      "#{__MODULE__} handle_events took #{time / 1_000}ms"
    end)

    state = %{state | timer: nil}
    {:noreply, [merged], state}
  end

  def handle_info(msg, state) do
    super(msg, state)
  end
end
