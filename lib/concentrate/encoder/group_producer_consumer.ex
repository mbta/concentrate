defmodule Concentrate.Encoder.GroupProducerConsumer do
  @moduledoc """
  ProducerConsumer which groups the parsed data into {trip, vehicles, stop
  time updates} tuples.

  Since the encoders all work with this format, it saves us a bit of time to
  only do it once.
  """
  use GenStage
  require Logger
  alias Concentrate.Encoder.GTFSRealtimeHelpers
  @start_link_opts [:name]

  def start_link(opts) do
    start_link_opts = Keyword.take(opts, @start_link_opts)
    opts = Keyword.drop(opts, @start_link_opts)
    GenStage.start_link(__MODULE__, opts, start_link_opts)
  end

  @impl GenStage
  def init(opts) do
    opts = Keyword.take(opts, [:subscribe_to, :dispatcher])
    opts = Keyword.put_new(opts, :dispatcher, GenStage.BroadcastDispatcher)
    {:producer_consumer, nil, opts}
  end

  @impl GenStage
  def handle_events(events, _from, state) do
    data = List.last(events)
    grouped = GTFSRealtimeHelpers.group(data)
    {:noreply, [grouped], state}
  end
end
