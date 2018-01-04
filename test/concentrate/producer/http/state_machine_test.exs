defmodule Concentrate.Producer.HTTP.StateMachineTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Producer.HTTP.StateMachine
  import ExUnit.CaptureLog

  describe "message/2" do
    test "does not log an error on :closed errors" do
      machine = init("url", [])

      for reason <- [:closed, {:closed, :timeout}] do
        error = %HTTPoison.Error{reason: reason}

        log =
          capture_log([level: :error], fn ->
            _ = message(machine, error)
          end)

        assert log == ""
      end
    end

    test "does log other errors" do
      machine = init("url", [])
      error = %HTTPoison.Error{reason: :unknown_error}

      log =
        capture_log([level: :error], fn ->
          _ = message(machine, error)
        end)

      assert log =~ ":unknown_error"
    end

    test "receiving the same body twice does not send a second message" do
      machine = init("url", [])

      messages = [
        %HTTPoison.AsyncStatus{code: 200},
        %HTTPoison.AsyncHeaders{headers: []},
        %HTTPoison.AsyncChunk{chunk: "body"},
        %HTTPoison.AsyncEnd{},
        %HTTPoison.AsyncStatus{code: 200},
        %HTTPoison.AsyncHeaders{headers: []},
        %HTTPoison.AsyncChunk{chunk: "body"},
        %HTTPoison.AsyncEnd{}
      ]

      initial = {machine, [], []}

      {_machine, bodies, _messages} =
        Enum.reduce(messages, initial, fn message, {machine, _, _} ->
          message(machine, message)
        end)

      assert bodies == []
    end
  end
end
