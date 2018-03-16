defmodule Concentrate.Sink.S3Test do
  @moduledoc false
  use ExUnit.Case
  import Concentrate.Sink.S3

  describe "start_link/2" do
    setup :test_pid

    test "writes a JSON file" do
      {:ok, _pid} = start_link([bucket: "bucket"], {"a.json", "a body"})
      assert_receive {:ex_aws, first_message}

      assert first_message.path == "a.json"
      assert first_message.body == "a body"
      assert first_message.headers["content-type"] == "application/json"
    end

    test "writes a protobuf file" do
      {:ok, _pid} = start_link([bucket: "bucket"], {"b.pb", "b body"})
      assert_receive {:ex_aws, second_message}

      assert second_message.path == "b.pb"
      assert second_message.body == "b body"
      assert second_message.headers["content-type"] == "application/x-protobuf"
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
