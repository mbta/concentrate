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
  @filters Application.get_env(:concentrate, :group_filters)

  def start_link(opts) do
    start_link_opts = Keyword.take(opts, @start_link_opts)
    opts = Keyword.drop(opts, @start_link_opts)
    GenStage.start_link(__MODULE__, opts, start_link_opts)
  end

  @impl GenStage
  def init(opts) do
    state = build_filters(Keyword.get(opts, :filters, @filters))
    opts = Keyword.take(opts, ~w(subscribe_to buffer_size dispatcher)a)
    opts = Keyword.put_new(opts, :dispatcher, GenStage.BroadcastDispatcher)
    {:producer_consumer, state, opts}
  end

  @impl GenStage
  def handle_events(events, _from, state) do
    data = List.last(events)

    grouped =
      data
      |> GTFSRealtimeHelpers.group()
      |> filter(state)

    {:noreply, [grouped], state}
  end

  defp build_filters(filters) do
    for filter <- filters do
      fun =
        case filter do
          filter when is_atom(filter) ->
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
        {_, [], []} -> []
        other -> [other]
      end
    end
  end

  defp filter(groups, filters) do
    Enum.reduce(filters, groups, fn filter, groups -> Enum.flat_map(groups, filter) end)
  end
end
