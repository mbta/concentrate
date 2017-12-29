defmodule Concentrate.Filter.ProducerConsumer do
  @moduledoc """
  ProducerConsumer which applies the set of filters to the given events.
  """
  use GenStage
  alias Concentrate.Filter
  @start_link_opts [:name]

  def start_link(opts) do
    start_link_opts = Keyword.take(opts, @start_link_opts)
    opts = Keyword.drop(opts, @start_link_opts)
    GenStage.start_link(__MODULE__, opts, start_link_opts)
  end

  @impl GenStage
  def init(opts) do
    {filters, opts} = Keyword.pop(opts, :filters, [])
    opts = Keyword.put_new(opts, :dispatcher, GenStage.BroadcastDispatcher)

    {:producer_consumer, filters, opts}
  end

  @impl GenStage
  def handle_events(events, _from, filters) do
    filtered =
      events
      |> List.last()
      |> Filter.run(filters)

    {:noreply, [filtered], filters}
  end
end
