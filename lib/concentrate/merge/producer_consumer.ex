defmodule Concentrate.Merge.ProducerConsumer do
  @moduledoc """
  ProducerConsumer which merges the data given to it and outputs the merged data.
  """
  use GenStage
  alias Concentrate.Merge
  @start_link_opts [:name]

  def start_link(opts \\ []) do
    start_link_opts = Keyword.take(opts, @start_link_opts)
    opts = Keyword.drop(opts, @start_link_opts)
    GenStage.start_link(__MODULE__, opts, start_link_opts)
  end

  @impl GenStage
  def init(opts) do
    opts = Keyword.take(opts, [:subscribe_to])
    {:producer_consumer, %{}, opts}
  end

  @impl GenStage
  def handle_events(events, from, state) do
    latest_data = List.last(events)
    state = Map.put(state, from, latest_data)

    merged =
      state
      |> Stream.flat_map(fn {_from, data} -> data end)
      |> Merge.merge()

    {:noreply, [merged], state}
  end
end
