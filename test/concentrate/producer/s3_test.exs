defmodule Concentrate.Producer.S3Test do
  @moduledoc false
  use ExUnit.Case

  alias __MODULE__.FakeAws
  alias Concentrate.Parser.SignsConfig
  alias Concentrate.Producer.S3

  require Logger

  defmodule FakeAws do
    def start_link do
      Agent.start_link(fn -> [] end, name: __MODULE__)
    end

    def mock_responses(responses) do
      Agent.update(__MODULE__, fn _ -> responses end)
    end

    def request(%ExAws.Operation.S3{}) do
      {status, body, headers} =
        Agent.get_and_update(__MODULE__, fn
          [{status, body, headers} | rest] -> {{status, body, headers}, rest}
          [{status, body} | rest] -> {{status, body, []}, rest}
          [] -> {{304, "", []}, []}
        end)

      {:ok,
       %{
         status_code: status,
         headers: headers,
         body: body
       }}
    end
  end

  setup do
    {:ok, _pid} = FakeAws.start_link()
    :ok
  end

  describe "init/1" do
    test "initializes state" do
      expected_state = %Concentrate.Producer.S3.State{
        bucket: "bucket",
        etag: nil,
        ex_aws: ExAws,
        fetch_after: 1000,
        last_modified: nil,
        next_fetch_ref: nil,
        object: "/object",
        parser_opts: [],
        parser: &SignsConfig.parse/2,
        url: "s3://bucket/object"
      }

      assert {:producer, state, _} =
               S3.init({"s3://bucket/object", [parser: SignsConfig, fetch_after: 1_000]})

      assert is_integer(Map.get(state, :last_fetch))
      assert ^expected_state = Map.put(state, :last_fetch, nil)
    end
  end

  describe "handle_demand/2" do
    setup :setup_state

    test "sets next fetch", %{state: state} do
      assert %{next_fetch_ref: nil} = state
      {:noreply, [], state} = S3.handle_demand(1, state)
      assert %{next_fetch_ref: ref} = state
      refute is_nil(ref)
      assert_receive :fetch
    end
  end

  describe "handle_info/2" do
    setup :setup_state

    test "fetches s3 object", %{state: state} do
      response1 = {200, encode_response([{"Red", 0, "1", "normal"}, {"Red", 1, "1", "normal"}])}
      response2 = {200, encode_response([{"Red", 0, "1", "flagged"}, {"Red", 1, "1", "normal"}])}
      response3 = {200, encode_response([{"Red", 0, "1", "normal"}, {"Red", 1, "1", "normal"}])}

      FakeAws.mock_responses([response1, response2, response3])

      {:noreply, [:empty], _state} = S3.handle_info(:fetch, state)

      {:noreply, [%{route_id: "Red", direction_id: 0, stop_id: "1"}], _state} =
        S3.handle_info(:fetch, state)

      {:noreply, [:empty], _state} = S3.handle_info(:fetch, state)
    end
  end

  defp setup_state(_) do
    {:producer, state, _} =
      S3.init({"s3://bucket/object", [ex_aws: FakeAws, parser: SignsConfig, fetch_after: 1_000]})

    {:ok, state: state}
  end

  defp encode_response(stops_entries) do
    Jason.encode!(%{
      stops:
        Enum.map(stops_entries, fn {route_id, direction_id, stop_id, predictions} ->
          %{
            route_id: route_id,
            direction_id: direction_id,
            stop_id: stop_id,
            predictions: predictions
          }
        end)
    })
  end
end
