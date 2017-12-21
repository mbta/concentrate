defmodule Concentrate.Producer.HTTP do
  @moduledoc """
  GenStage Producer which fulfills demand by fetching from an HTTP Server.
  """
  use GenStage
  require Logger
  @start_link_opts [:name]

  defmodule State do
    @moduledoc """
    Module for keeping track of the state for an HTTP producer.
    """
    defstruct url: "",
              body: [],
              headers: [],
              parser: nil,
              fetch_after: 5_000,
              demand: 0
  end

  alias __MODULE__.State

  def start_link({url, opts}) when is_list(opts) do
    start_link_opts = Keyword.take(opts, @start_link_opts)
    opts = Keyword.drop(opts, @start_link_opts)
    GenStage.start_link(__MODULE__, {url, opts}, start_link_opts)
  end

  @impl GenStage
  def init({url, opts}) do
    state = Enum.reduce(opts, %State{url: url}, &update_state_opt(&2, &1))
    {:producer, state}
  end

  defp update_state_opt(state, key_value) do
    case key_value do
      {:parser, module} when is_atom(module) ->
        %{state | parser: &module.parse/1}

      {:parser, fun} when is_function(fun, 1) ->
        %{state | parser: fun}

      {:fetch_after, fetch_after} ->
        %{state | fetch_after: fetch_after}
    end
  end

  @impl GenStage
  def handle_info(:fetch, state) do
    send(self(), {:fetch, state.url})
    {:noreply, [], state}
  end

  def handle_info({:fetch, url}, state) do
    {:ok, _} = HTTPoison.get(url, state.headers, stream_to: self())
    {:noreply, [], state}
  end

  def handle_info(%HTTPoison.AsyncStatus{code: 200}, state) do
    {:noreply, [], state}
  end

  def handle_info(%HTTPoison.AsyncStatus{code: 301}, state) do
    {:noreply, [], %{state | body: {:redirect, :permanent}}}
  end

  def handle_info(%HTTPoison.AsyncStatus{code: 302}, state) do
    {:noreply, [], %{state | body: {:redirect, :temporary}}}
  end

  def handle_info(%HTTPoison.AsyncStatus{code: 304}, state) do
    Logger.info(fn ->
      "#{__MODULE__}: #{inspect(state.url)} not modified"
    end)

    {:noreply, [], %{state | body: :halt}}
  end

  def handle_info(%HTTPoison.AsyncStatus{code: code}, state) do
    Logger.warn(fn ->
      "#{__MODULE__}: #{inspect(state.url)} unexpected code #{inspect(code)}"
    end)

    {:noreply, [], %{state | body: :halt}}
  end

  def handle_info(%HTTPoison.AsyncHeaders{}, %{body: :halt} = state) do
    {:noreply, [], state}
  end

  def handle_info(%HTTPoison.AsyncHeaders{headers: headers}, %{body: {:redirect, type}} = state) do
    {_, new_location} =
      Enum.find(headers, fn {header, _} -> String.downcase(header) == "location" end)

    {:noreply, [], %{state | body: {:redirect, type, new_location}}}
  end

  def handle_info(%HTTPoison.AsyncHeaders{headers: resp_headers}, state) do
    # grab the cache headers
    headers =
      Enum.reduce(resp_headers, [], fn {header, value}, acc ->
        cond do
          String.downcase(header) == "last-modified" ->
            [{"if-modified-since", value} | acc]

          String.downcase(header) == "etag" ->
            [{"if-none-match", value} | acc]

          true ->
            acc
        end
      end)

    state = %{state | headers: headers}
    {:noreply, [], state}
  end

  def handle_info(%HTTPoison.AsyncChunk{chunk: chunk}, %{body: iolist} = state)
      when is_list(iolist) do
    {:noreply, [], %{state | body: [iolist, chunk]}}
  end

  def handle_info(%HTTPoison.AsyncChunk{}, state) do
    {:noreply, [], state}
  end

  def handle_info(%HTTPoison.AsyncEnd{}, state) do
    events = parse_body(state)

    case next_message_after_fetch(state, events) do
      {message, after_time} ->
        Process.send_after(self(), message, after_time)

      _ ->
        :ok
    end

    state = update_state(state)

    {:noreply, events, state}
  end

  def handle_info(message, state) do
    super(message, state)
  end

  @impl GenStage
  def handle_demand(new_demand, %{demand: existing_demand} = state) do
    send(self(), :fetch)
    {:noreply, [], %{state | demand: new_demand + existing_demand}}
  end

  defp parse_body(%{body: iolist} = state) when is_list(iolist) do
    parsed = state.parser.(IO.iodata_to_binary(iolist))

    Logger.info(fn ->
      "#{__MODULE__}: #{inspect(state.url)} got #{length(parsed)} records"
    end)

    [parsed]
  catch
    error ->
      Logger.error(fn ->
        "#{__MODULE__}: #{inspect(state.url)} parse error: #{inspect(error)}"
      end)

      []
  end

  defp parse_body(_state) do
    []
  end

  defp next_message_after_fetch(%{body: {:redirect, _, url}}, _) do
    # refetch immediately if we got redirected
    {{:fetch, url}, 0}
  end

  defp next_message_after_fetch(%{demand: demand}, [_ | _])
       when demand < 2 do
    # if we got data and there's no future demand, don't do anything for now
    nil
  end

  defp next_message_after_fetch(%{fetch_after: fetch_after}, _) do
    # otherwise, schedule a fetch
    {:fetch, fetch_after}
  end

  defp update_state(%{body: {:redirect, :permanent, url}} = state) do
    # update our URL if we got permanemtly redirected
    update_state(%{state | url: url, body: []})
  end

  defp update_state(state) do
    # decrease demand by one
    %{state | body: [], demand: state.demand - 1}
  end
end
