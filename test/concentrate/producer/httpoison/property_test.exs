defmodule Concentrate.Producer.HTTPoison.PropertyTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties

  setup_all do
    {:ok, _} = Application.ensure_all_started(:hackney)
    {:ok, _} = Application.ensure_all_started(:bypass)
    {:ok, _} = Application.ensure_all_started(:httpoison)

    on_exit(fn ->
      Application.stop(:hackney)
    end)

    {:ok, _} =
      start_supervised(%{
        id: :hackney_pool,
        start: {:hackney_pool, :start_link, [:http_producer_pool, []]},
        type: :worker,
        restart: :permanent
      })

    :ok
  end

  property "returns all the bodies" do
    check all(
            bodies <- list_of(bodies(), min_length: 1, max_length: 10),
            demand <- demand(bodies)
          ) do
      {bypass, url} = url_for_bodies(bodies)

      {:ok, producer} =
        start_supervised(
          {Concentrate.Producer.HTTPoison, {url, parser: &parser/1, fetch_after: 1}}
        )

      expected_body_count = expected_count(bodies)

      passed? = receive_count?(producer, demand, expected_body_count)
      stop_supervised(producer)
      Bypass.down(bypass)
      assert passed?
    end
  end

  property "returns all the bodies even with a fallback" do
    check all(
            bodies <- list_of(bodies(), min_length: 1, max_length: 10),
            fallback_bodies <- list_of(bodies(), min_length: 1, max_length: 10),
            demand <- demand(bodies ++ fallback_bodies)
          ) do
      {bypass, url} = url_for_bodies(bodies)
      {fallback_bypass, fallback_url} = url_for_bodies(fallback_bodies)

      {:ok, producer} =
        start_supervised(
          {Concentrate.Producer.HTTPoison,
           {url,
            fallback_url: fallback_url,
            content_warning_timeout: 10,
            parser: &parser/1,
            fetch_after: 1}}
        )

      expected_body_count = expected_count(bodies) + expected_count(fallback_bodies)
      passed? = receive_count?(producer, demand, expected_body_count)
      stop_supervised(producer)
      Bypass.down(bypass)
      Bypass.down(fallback_bypass)
      assert passed?
    end
  end

  defp parser(""), do: []
  defp parser(binary) when is_binary(binary), do: [binary]

  defp bodies do
    StreamData.frequency([
      {1, StreamData.constant("1")},
      {1, StreamData.constant("2")},
      {2, StreamData.constant("")}
    ])
  end

  defp demand(bodies) do
    # don't request more demand than we have bodies
    max_demand = min(length(bodies), 5)
    StreamData.integer(1..max_demand)
  end

  defp url_for_bodies(bodies) do
    {:ok, agent} = Agent.start_link(fn -> bodies end)
    bypass = open_bypass()
    # return each body in turn
    Bypass.expect(bypass, fn conn ->
      body =
        Agent.get_and_update(agent, fn
          [h | t] -> {h, t}
          [] -> {"", []}
        end)

      Plug.Conn.send_resp(conn, 200, body)
    end)

    Bypass.pass(bypass)
    {bypass, "http://127.0.0.1:#{bypass.port}/"}
  end

  defp open_bypass do
    # sometimes Bypass tries to re-use a port, causing an error. This retries
    # in that case.
    case Bypass.open() do
      %Bypass{} = bypass -> bypass
      _ -> open_bypass()
    end
  end

  defp expected_count(bodies) do
    # number of bodies which aren't the empty string, ignoring consecutive
    # duplicates
    bodies
    |> Enum.dedup()
    |> Enum.count(&(&1 != ""))
  end

  defp receive_count?(producer, demand, count) do
    task =
      Task.async(fn ->
        [{producer, max_demand: demand}]
        |> GenStage.stream()
        |> Enum.take(count)
      end)

    passed? =
      case Task.yield(task, 5000) || Task.shutdown(task) do
        {:ok, _} ->
          true

        nil ->
          false
      end

    :ok = stop_supervised(Concentrate.Producer.HTTPoison)
    passed?
  end
end
