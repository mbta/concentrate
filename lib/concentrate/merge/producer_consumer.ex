defmodule Concentrate.Merge.ProducerConsumer do
  @moduledoc """
  ProducerConsumer which merges the data given to it and outputs the merged data.
  """
  use GenStage
  alias Concentrate.Merge

  def start_link(opts \\ []) do
    GenStage.start_link(__MODULE__, opts)
  end

  @impl GenStage
  def init(opts) do
    opts = Keyword.take(opts, [:subscribe_to])
    {:producer_consumer, %{}, opts}
  end

  @impl GenStage
  def handle_events(events, from, state) do
    latest_data = Merge.merge(List.last(events))
    state = Map.put(state, from, latest_data)

    merged =
      state
      |> Map.values()
      |> Stream.concat()
      |> Merge.merge()

    {:noreply, [merged], state}
  end
end
