defmodule Concentrate.Sink.MqttTest do
  @moduledoc false
  use ExUnit.Case
  import Concentrate.Sink.Mqtt

  @moduletag :capture_log

  setup do
    prefix = "concentrate/test_sink/#{System.unique_integer()}/"

    config = [
      url: "mqtt://test.mosquitto.org",
      prefix: prefix
    ]

    start_supervised!(
      {EmqttFailover.Connection,
       configs: config[:url],
       handler: {EmqttFailover.ConnectionHandler.Parent, parent: self(), topics: ["#{prefix}#"]},
       backoff: 50}
    )

    receive do
      {:connected, _} -> :ok
    after
      2_000 ->
        raise "unable to connect to MQTT broker"
    end

    {:ok, config: config}
  end

  describe "handle_events/2" do
    test "writes the given file to the topic, gzip-encoded", %{config: config} do
      filename = "file_#{System.unique_integer()}"
      body = "#{System.unique_integer()}"

      start_with_events(config, [{filename, body}])

      expected_topic = "#{config[:prefix]}#{filename}"

      assert_receive {:message, _, message = %EmqttFailover.Message{topic: ^expected_topic}},
                     5_000

      assert :zlib.gunzip(message.payload) == body
    end

    test "can write a partial feed, gzip-encoded", %{config: config} do
      filename = "file_#{System.unique_integer()}"
      body = "#{System.unique_integer()}"

      start_with_events(config, [{filename, body, partial?: true}])

      expected_topic = "#{config[:prefix]}#{filename}"

      assert_receive {:message, _, message = %EmqttFailover.Message{topic: ^expected_topic}},
                     5_000

      assert :zlib.gunzip(message.payload) == body
    end
  end

  defp start_with_events(config, events) do
    {:ok, producer} = GenStage.from_enumerable(events)
    {:ok, _client} = start_link(config ++ [subscribe_to: [producer]])
    :ok
  end
end
