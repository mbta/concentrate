defmodule Concentrate.Producer.Mqtt do
  @moduledoc """
  GenStage Producer which fulfills demand by receiving events from an MQTT broker.
  """
  use GenStage
  require Logger
  alias EmqttFailover.Connection
  @start_link_opts [:name]

  defmodule State do
    @moduledoc false
    defstruct [:url, :parser, :parser_opts]
  end

  alias __MODULE__.State

  def start_link({url, opts}) when is_binary(url) and is_list(opts) do
    start_link_opts = Keyword.take(opts, @start_link_opts)
    opts = Keyword.drop(opts, @start_link_opts)
    GenStage.start_link(__MODULE__, {url, opts}, start_link_opts)
  end

  @impl GenStage
  def init({url, opts}) do
    {parser, parser_opts} =
      case Keyword.fetch!(opts, :parser) do
        module when is_atom(module) ->
          {&module.parse/2, []}

        {module, opts} when is_atom(module) and is_list(opts) ->
          {&module.parse/2, opts}

        fun when is_function(fun, 2) ->
          {fun, []}
      end

    start_opts = emqtt_opts(url, opts)
    {:ok, _client} = Connection.start_link(start_opts)

    {
      :producer,
      %State{url: url, parser: parser, parser_opts: parser_opts},
      dispatcher: GenStage.BroadcastDispatcher
    }
  end

  @impl GenStage
  def handle_demand(_demand, state) do
    # we don't care, buffering takes care of any demand management
    {:noreply, [], state}
  end

  @impl GenStage
  def handle_info({:message, _pid, msg}, state) do
    parsed =
      state.parser.(
        decode_payload(msg.payload),
        [feed_url: state.url <> "/" <> msg.topic] ++ state.parser_opts
      )

    {:noreply, [parsed], state}
  end

  def handle_info({:connected, _pid}, state) do
    {:noreply, [], state}
  end

  def handle_info({:disconnected, _pid, _reason}, state) do
    {:noreply, [], state}
  end

  defp emqtt_opts(url, opts) do
    configs = Concentrate.Mqtt.configs([url: url] ++ opts)

    handler =
      {EmqttFailover.ConnectionHandler.Parent, parent: self(), topics: opts[:topics] || []}

    [
      configs: configs,
      client_id: EmqttFailover.client_id(prefix: "cntrt-prd"),
      backoff: {1_000, 60_000, :jitter},
      handler: handler,
      backoff: Keyword.get(opts, :backoff)
    ]
  end

  defp decode_payload(<<0x1F, 0x8B, _::binary>> = payload) do
    # gzip encoded
    :zlib.gunzip(payload)
  end

  defp decode_payload(payload) when is_binary(payload) do
    payload
  end
end
