defmodule Concentrate.Encoder.ProducerConsumer do
  @moduledoc """
  """
  use GenStage
  require Logger
  @start_link_opts [:name]

  def start_link(opts) do
    start_link_opts = Keyword.take(opts, @start_link_opts)
    opts = Keyword.drop(opts, @start_link_opts)
    GenStage.start_link(__MODULE__, opts, start_link_opts)
  end

  @impl GenStage
  def init(opts) do
    {files, opts} = Keyword.pop(opts, :files, [])

    state =
      for {filename, encoder} <- files do
        encoder =
          case encoder do
            module when is_atom(module) ->
              Code.ensure_loaded(module)

              if function_exported?(module, :encode_groups, 1) do
                &module.encode_groups/1
              else
                &module.encode/1
              end

            fun when is_function(fun, 1) ->
              fun
          end

        {filename, encoder}
      end

    {:producer_consumer, state, opts}
  end

  @impl GenStage
  def handle_events(events, _from, state) do
    data = List.last(events)

    responses =
      for {filename, encoder} <- state do
        {time, encoded} = :timer.tc(encoder, [data])

        Logger.debug(fn ->
          "#{__MODULE__} encoded #{inspect(filename)} in #{time / 1000}ms"
        end)

        {filename, encoded}
      end

    {:noreply, responses, state, :hibernate}
  end
end
