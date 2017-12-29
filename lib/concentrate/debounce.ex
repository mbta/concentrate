defmodule Concentrate.Debounce do
  @moduledoc """
  Producer consumer which only sends events once per a given timeframe.
  """
  use GenStage
  @start_link_opts [:name]

  def start_link(opts) do
    start_link_opts = Keyword.take(opts, @start_link_opts)
    opts = Keyword.drop(opts, @start_link_opts)
    GenStage.start_link(__MODULE__, opts, start_link_opts)
  end

  @impl GenStage
  def init(opts) do
    {timeout, opts} = Keyword.pop(opts, :timeout, 1_000)
    state = %{timeout: timeout, timer: nil, events: []}
    {:producer_consumer, state, opts}
  end

  @impl GenStage
  def handle_events(events, _from, state) do
    event = List.last(events)
    state = %{state | events: [event]}

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
    events = state.events
    state = %{state | events: [], timer: nil}
    {:noreply, events, state}
  end
end
