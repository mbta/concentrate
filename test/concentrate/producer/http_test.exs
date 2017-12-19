defmodule Concentrate.Producer.HTTPTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Producer.HTTP
  import Plug.Conn, only: [get_req_header: 2, put_resp_header: 3, send_resp: 3]

  describe "init/1" do
    test "parser can be a module" do
      defmodule TestParser do
        @behaviour Concentrate.Parser
        def parse(_body), do: []
      end

      assert {:producer, state} = init({"url", parser: __MODULE__.TestParser})
      assert state.parser == &__MODULE__.TestParser.parse/1
    end
  end

  describe "handle_info/2" do
    @tag :capture_log
    test "ignores unknown messages" do
      state = %Concentrate.Producer.HTTP.State{}
      assert {:noreply, [], ^state} = handle_info(:unknown, state)
    end
  end

  describe "bypass" do
    setup do
      Application.ensure_all_started(:bypass)
      Application.ensure_all_started(:httpoison)
      bypass = Bypass.open()
      {:ok, bypass: bypass}
    end

    test "does not connect without a consumer", %{bypass: bypass} do
      Bypass.down(bypass)

      {:ok, _producer} = start_producer(bypass)

      # make sure the producer doesn't crash
      assert :timer.sleep(50)
    end

    test "sends the result of parsing", %{bypass: bypass} do
      Bypass.expect_once(bypass, fn conn ->
        send_resp(conn, 200, "body")
      end)

      {:ok, producer} = start_producer(bypass)
      assert take_events(producer, 1) == [["body"]]
    end

    test "schedules a fetch again", %{bypass: bypass} do
      {:ok, agent} = response_agent()

      agent
      |> add_response(fn conn ->
        send_resp(conn, 200, "first")
      end)
      |> add_response(fn conn ->
        send_resp(conn, 200, "second")
      end)

      Bypass.expect(bypass, fn conn -> agent_response(agent, conn) end)

      {:ok, producer} = start_producer(bypass, fetch_after: 50)

      assert take_events(producer, 2) == [["first"], ["second"]]
    end

    test "if there's a cached response, retries again", %{bypass: bypass} do
      {:ok, agent} = response_agent()

      agent
      |> add_response(fn conn ->
        conn
        |> put_resp_header("Last-Modified", "last mod")
        |> put_resp_header("ETag", "tag")
        |> send_resp(200, "first")
      end)
      |> add_response(fn conn ->
        assert get_req_header(conn, "if-modified-since") == ["last mod"]
        assert get_req_header(conn, "if-none-match") == ["tag"]
        send_resp(conn, 304, "not modified")
      end)
      |> add_response(fn conn ->
        assert get_req_header(conn, "if-modified-since") == ["last mod"]
        assert get_req_header(conn, "if-none-match") == ["tag"]
        send_resp(conn, 200, "second")
      end)

      Bypass.expect(bypass, fn conn -> agent_response(agent, conn) end)

      {:ok, producer} = start_producer(bypass, fetch_after: 50)
      assert take_events(producer, 3) == [["first"], ["second"], ["agent"]]
    end

    defp start_producer(bypass, opts \\ []) do
      url = "http://127.0.0.1:#{bypass.port}/"
      opts = Keyword.put_new(opts, :parser, fn body -> [body] end)

      start_link(url, opts)
    end

    defp take_events(producer, event_count) do
      [{producer, max_demand: event_count}]
      |> GenStage.stream()
      |> Enum.take(event_count)
    end

    defp response_agent do
      Agent.start_link(fn -> [] end)
    end

    defp add_response(agent, fun) do
      :ok = Agent.update(agent, fn funs -> funs ++ [fun] end)
      agent
    end

    defp agent_response(agent, conn) do
      fun =
        Agent.get_and_update(agent, fn
          [] -> {&default_response/1, []}
          [fun | funs] -> {fun, funs}
        end)

      fun.(conn)
    end

    defp default_response(conn) do
      send_resp(conn, 200, "agent")
    end
  end
end
