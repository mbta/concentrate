defmodule Concentrate.Producer.MqttTest do
  @moduledoc false
  use ExUnit.Case

  alias Concentrate.Producer.Mqtt

  setup do
    old_level = Logger.level()
    on_exit(fn -> Logger.configure(level: old_level) end)
    Logger.configure(level: :warning)

    {:ok, emqtt_writer} =
      :emqtt.start_link(%{
        host: "localhost",
        port: 1883
      })

    {:ok, _} = :emqtt.connect(emqtt_writer)

    test_topic = "concentrate/test_producer/#{System.unique_integer()}"

    {:ok, %{emqtt_writer: emqtt_writer, test_topic: test_topic}}
  end

  test "can dispatch events from an MQTT stream", %{
    emqtt_writer: emqtt_writer,
    test_topic: test_topic
  } do
    config = {
      url = "mqtt://localhost:1883",
      topics: [test_topic], parser: __MODULE__.PassThroughParser
    }

    {:ok, pid} = Mqtt.start_link(config)

    :emqtt.publish(emqtt_writer, test_topic, %{}, "payload", qos: 1, retain: true)

    [[{:parsed, body, opts}]] = Enum.take(GenStage.stream([pid]), 1)
    assert <<_::binary>> = body
    assert String.starts_with?(Keyword.fetch!(opts, :feed_url), url <> "/")
  end

  test "can accept a function as a parser", %{
    emqtt_writer: emqtt_writer,
    test_topic: test_topic
  } do
    config = {
      "mqtt://localhost:1883",
      topics: [test_topic], parser: &__MODULE__.PassThroughParser.parse/2
    }

    {:ok, pid} = Mqtt.start_link(config)

    :emqtt.publish(emqtt_writer, test_topic, %{}, "payload", qos: 1, retain: true)

    [[{:parsed, body, _opts}]] = Enum.take(GenStage.stream([pid]), 1)
    assert <<_::binary>> = body
  end

  test "can authenticate with a password", %{
    emqtt_writer: emqtt_writer,
    test_topic: test_topic
  } do
    config = {
      "mqtt://localhost:1883",
      username: "test_user",
      password: "test_password",
      topics: [test_topic],
      parser: __MODULE__.PassThroughParser
    }

    {:ok, pid} = Mqtt.start_link(config)

    :emqtt.publish(emqtt_writer, test_topic, %{}, "payload", qos: 1, retain: true)

    assert [[{:parsed, _, _}]] = Enum.take(GenStage.stream([pid]), 1)
  end

  # we expect a warning here
  @tag :capture_log
  test "can authenticate with one of multiple passwords", %{
    emqtt_writer: emqtt_writer,
    test_topic: test_topic
  } do
    config = {
      "mqtt://localhost:1883",
      username: "test_user",
      password: "notvalid test_password",
      topics: [test_topic],
      backoff: 0,
      parser: __MODULE__.PassThroughParser
    }

    {:ok, pid} = Mqtt.start_link(config)

    :emqtt.publish(emqtt_writer, test_topic, %{}, "payload", qos: 1, retain: true)

    assert [[{:parsed, _, _}]] = Enum.take(GenStage.stream([pid]), 1)
  end

  test "can accept gzip-encoded payloads" do
    test_topic = "concentrate/test_producer/#{System.unique_integer()}"
    payload = "payload"

    config = {
      "mqtt://localhost:1883",
      topics: [test_topic], parser: __MODULE__.PassThroughParser
    }

    {:ok, writer} =
      :emqtt.start_link(%{
        host: "localhost",
        port: 1883
      })

    {:ok, _} = :emqtt.connect(writer)
    :emqtt.publish(writer, test_topic, %{}, :zlib.gzip(payload), qos: 1, retain: true)

    {:ok, pid} = Mqtt.start_link(config)

    assert [[{:parsed, ^payload, _}]] = Enum.take(GenStage.stream([pid]), 1)
  end

  defmodule PassThroughParser do
    @moduledoc false
    @behaviour Concentrate.Parser

    def parse(body, opts) do
      [{:parsed, body, opts}]
    end
  end
end
