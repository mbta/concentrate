defmodule Concentrate.Producer.HTTP.StateMachineTest do
  @moduledoc false
  use ExUnit.Case
  import Concentrate.Producer.HTTP.StateMachine
  import ExUnit.CaptureLog

  setup_all do
    Application.ensure_all_started(:bypass)
    Application.ensure_all_started(:httpoison)
    :ok
  end

  describe "fetch/1" do
    test "fetches immediately the first time" do
      machine = init("url", [])
      assert {_machine, [], [{_, 0}]} = fetch(machine)
    end

    test "if we had a success in the past, doesn't refetch immediately" do
      machine = init("url", [])
      {machine, _, _} = message(machine, {:http_response, make_resp([])})
      assert {_machine, _, [{_, delay}]} = fetch(machine)
      assert delay > 0
    end

    test "if we had a success more than `fetch_after` in the past, fetches immediately" do
      machine = init("url", fetch_after: 10)
      {machine, _, _} = message(machine, {:http_response, make_resp([])})
      :timer.sleep(11)
      assert {_machine, _, [{_, 0}]} = fetch(machine)
    end
  end

  describe "message/2" do
    test "does not log an error on :closed or :timeout errors" do
      machine = init("url", [])

      for reason <- [:closed, {:closed, :timeout}, :timeout] do
        error = {:http_error, reason}

        log =
          capture_log([level: :error], fn ->
            assert {_machine, [], [{{:fetch, _}, _}]} = message(machine, error)
          end)

        assert log == ""
      end
    end

    test "does log other errors" do
      machine = init("url", [])
      error = {:http_error, :unknown_error}

      log =
        capture_log([level: :error], fn ->
          assert {_machine, [], [{{:fetch, _}, _}]} = message(machine, error)
        end)

      assert log =~ ":unknown_error"
    end

    test "logs a error if we have't gotten content since a timeout" do
      opts = [content_warning_timeout: 0]

      messages = [
        {:http_response, make_resp(body: "body")},
        fn -> :timer.sleep(5) end,
        {:http_response, make_resp(code: 304)}
      ]

      log =
        capture_log([level: :error], fn ->
          _ = run_machine("url", opts, messages)
        end)

      assert log =~ ~s("url")
      assert log =~ "has not been updated in"
    end

    test "does not log multiple warnings after the first timeout" do
      opts = [content_warning_timeout: 5]

      messages = [
        {:http_response, make_resp(body: "body")},
        {:http_response, make_resp(code: 304)},
        fn -> :timer.sleep(10) end,
        {:http_response, make_resp(code: 304)}
      ]

      log =
        capture_log([level: :error], fn ->
          _ = run_machine("url", opts, messages)
        end)

      # only one message (some content before, some content after)
      assert [_, _] = String.split(log, "[error]")
    end

    test "receiving the same body twice does not send a second message" do
      messages = [
        {:http_response, make_resp(body: "body")},
        {:http_response, make_resp(body: "body")}
      ]

      {_machine, bodies, messages} = run_machine("url", [], messages)

      assert bodies == []
      assert [{{:fetch, "url"}, timeout} | _] = messages
      assert timeout > 0
    end

    test "receiving an unknown code logs an warning and reschedules a fetch" do
      messages = [
        {:http_response, make_resp(code: 500)}
      ]

      fetch_after = 1000

      log =
        capture_log([level: :warn], fn ->
          assert {_machine, [], [{{:fetch, "url"}, ^fetch_after} | _]} =
                   run_machine("url", [fetch_after: fetch_after], messages)
        end)

      refute log == ""
    end
  end

  defp run_machine(url, opts, messages) do
    machine = init(url, opts)
    initial = {machine, [], []}

    Enum.reduce(messages, initial, fn message, {machine, _, _} ->
      case message do
        fun when is_function(fun, 0) ->
          fun.()
          {machine, [], []}

        message ->
          message(machine, message)
      end
    end)
  end

  defp make_resp(opts) do
    code = Keyword.get(opts, :code, 200)
    body = Keyword.get(opts, :body, "")
    headers = Keyword.get(opts, :headers, [])
    %HTTPoison.Response{status_code: code, body: body, headers: headers}
  end
end
