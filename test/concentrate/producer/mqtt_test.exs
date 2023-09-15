defmodule Concentrate.Producer.MqttTest do
  @moduledoc false
  use ExUnit.Case

  alias Concentrate.Producer.Mqtt

  setup do
    old_level = Logger.level()
    on_exit(fn -> Logger.configure(level: old_level) end)
    Logger.configure(level: :warning)

    :ok
  end

  test "can dispatch events from an MQTT stream" do
    config = {
      url = "mqtt+ssl://test.mosquitto.org:8886",
      topics: ["home/#"], parser: __MODULE__.PassThroughParser
    }

    {:ok, pid} = Mqtt.start_link(config)

    [[{:parsed, body, opts}]] = Enum.take(GenStage.stream([pid]), 1)
    assert <<_::binary>> = body
    assert String.starts_with?(Keyword.fetch!(opts, :feed_url), url <> "/")
  end

  test "can accept a function as a parser" do
    config = {
      "mqtt+ssl://test.mosquitto.org:8886",
      topics: ["home/#"], parser: &__MODULE__.PassThroughParser.parse/2
    }

    {:ok, pid} = Mqtt.start_link(config)

    [[{:parsed, body, _opts}]] = Enum.take(GenStage.stream([pid]), 1)
    assert <<_::binary>> = body
  end

  test "can authenticate with a password" do
    config = {
      "mqtt://test.mosquitto.org:1884",
      username: "ro",
      password: "readonly",
      topics: ["home/#"],
      parser: __MODULE__.PassThroughParser
    }

    {:ok, pid} = Mqtt.start_link(config)

    assert [[{:parsed, _, _}]] = Enum.take(GenStage.stream([pid]), 1)
  end

  # we expect a warning here
  @tag :capture_log
  test "can authenticate with one of multiple passwords" do
    config = {
      "mqtt://test.mosquitto.org:1884",
      username: "ro",
      password: "notvalid readonly",
      topics: ["home/#"],
      backoff: 0,
      parser: __MODULE__.PassThroughParser
    }

    {:ok, pid} = Mqtt.start_link(config)

    assert [[{:parsed, _, _}]] = Enum.take(GenStage.stream([pid]), 1)
  end

  test "can accept gzip-encoded payloads" do
    test_topic = "concentrate/test_producer/#{System.unique_integer()}"
    payload = "payload"

    config = {
      "mqtt+ssl://test.mosquitto.org:8886",
      topics: [test_topic], parser: __MODULE__.PassThroughParser
    }

    {:ok, writer} =
      :emqtt.start_link(%{
        host: "test.mosquitto.org",
        port: 8885,
        username: "wo",
        password: "writeonly",
        ssl: true,
        ssl_opts: [verify: :verify_none]
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
