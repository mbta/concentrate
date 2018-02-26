defmodule Concentrate.Sink.S3Test do
  @moduledoc false
  use ExUnit.Case
  import ExUnit.CaptureLog
  import Concentrate.Sink.S3

  describe "handle_events/1" do
    setup :test_pid

    test "writes to each file" do
      {_, state, _} = init(bucket: "bucket")
      _ = handle_events([{"a.json", "a body"}, {"b.pb", "b body"}], :from, state)
      assert_receive {:ex_aws, first_message}
      assert_receive {:ex_aws, second_message}
      messages = Enum.sort_by([first_message, second_message], & &1.path)

      for message <- messages do
        assert message.bucket == "bucket"
        assert message.headers["x-amz-acl"] == "public-read"
      end

      # make sure they're in the same order, even when they're uploaded async
      [first_message, second_message] = messages
      assert first_message.path == "a.json"
      assert first_message.body == "a body"
      assert first_message.headers["content-type"] == "application/json"
      assert second_message.path == "b.pb"
      assert second_message.body == "b body"
      assert second_message.headers["content-type"] == "application/x-protobuf"
    end
  end

  describe "handle_info/2" do
    test "does not log a warning for ssl_closed messages" do
      {_, state, _} = init(bucket: "bucket")

      log =
        capture_log([level: :warn], fn ->
          assert {:noreply, [], ^state} = handle_info({:ssl_closed, :closed}, state)
        end)

      assert log == ""
    end

    test "logs a warning for other unknown messages" do
      {_, state, _} = init(bucket: "bucket")

      log =
        capture_log([level: :warn], fn ->
          assert {:noreply, [], ^state} = handle_info({:message, :unknown}, state)
        end)

      assert log =~ "unexpected message"
      assert log =~ ~s({:message, :unknown})
    end
  end

  defp test_pid(_) do
    # configures TestExAws to send us messages
    env = Application.get_env(:concentrate, Concentrate.TestExAws)

    on_exit(fn ->
      Application.put_env(:concentrate, Concentrate.TestExAws, env)
    end)

    env = Keyword.put(env || [], :pid, self())
    Application.put_env(:concentrate, Concentrate.TestExAws, env)
    :ok
  end
end
