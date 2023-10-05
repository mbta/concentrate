defmodule Concentrate.Sink.Mqtt do
  @moduledoc """
  Sink which publishes files to an MQTT topic.
  """
  use GenStage
  require Logger

  defstruct [:client, :prefix, :subscriptions]

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  @impl GenStage
  def init(opts) do
    configs = Concentrate.Mqtt.configs(opts)

    {:ok, client} =
      EmqttFailover.Connection.start_link(
        client_id: EmqttFailover.client_id(prefix: "cntrt-snk"),
        backoff: {1_000, 60_000, :jitter},
        configs: configs,
        handler: {EmqttFailover.ConnectionHandler.Parent, parent: self()}
      )

    state = %__MODULE__{
      client: client,
      prefix: opts[:prefix] || "",
      subscriptions: opts[:subscribe_to] || []
    }

    {:consumer, state}
  end

  @impl GenStage
  def handle_events(events, _from, state) do
    for event <- events do
      publish(event, state)
    end

    {:noreply, [], state}
  end

  @impl GenStage
  def handle_info({:connected, client}, %{client: client} = state) do
    for subscription <- state.subscriptions do
      GenStage.async_subscribe(self(), to: subscription)
    end

    {:noreply, [], %{state | subscriptions: []}}
  end

  def handle_info({:disconnected, client, _reason}, %{client: client} = state) do
    {:noreply, [], state}
  end

  defp publish({filename, body}, state) do
    publish({filename, body, []}, state)
  end

  defp publish({filename, body, opts}, state) do
    partial? = !!Keyword.get(opts, :partial?)
    topic = state.prefix <> filename
    payload = :zlib.gzip(body)

    message_opts =
      if partial? do
        [qos: 0]
      else
        [qos: 1, retain?: true]
      end

    message = struct!(%EmqttFailover.Message{topic: topic, payload: payload}, message_opts)

    case EmqttFailover.Connection.publish(state.client, message) do
      :ok ->
        _ =
          Logger.info(fn ->
            "#{__MODULE__} updated: \
partial?=#{partial?} \
topic=#{inspect(topic)} \
bytes=#{byte_size(payload)}"
          end)

      {:error, reason} ->
        _ =
          Logger.warning(fn ->
            "#{__MODULE__} unable to send: \
partial?=#{partial?} \
topic=#{inspect(topic)} \
reason=#{inspect(reason)}"
          end)
    end
  end
end
