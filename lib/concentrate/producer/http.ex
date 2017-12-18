defmodule Concentrate.Producer.HTTP do
  @moduledoc """
  GenStage Producer which fulfills demand by fetching from an HTTP Server.
  """
  use GenStage

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

  def start_link(url, opts) when is_list(opts) do
    GenStage.start_link(__MODULE__, {url, opts})
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
    {:ok, _} = HTTPoison.get(state.url, state.headers, stream_to: self())
    {:noreply, [], state}
  end

  def handle_info(%HTTPoison.AsyncStatus{code: 200}, state) do
    {:noreply, [], state}
  end

  def handle_info(%HTTPoison.AsyncStatus{code: 304}, state) do
    {:noreply, [], %{state | body: :halt}}
  end

  def handle_info(%HTTPoison.AsyncHeaders{}, %{body: :halt} = state) do
    {:noreply, [], state}
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

  def handle_info(%HTTPoison.AsyncChunk{}, %{body: :halt} = state) do
    {:noreply, [], state}
  end

  def handle_info(%HTTPoison.AsyncChunk{chunk: chunk}, state) do
    {:noreply, [], %{state | body: [state.body, chunk]}}
  end

  def handle_info(%HTTPoison.AsyncEnd{}, state) do
    events =
      if state.body == :halt do
        []
      else
        [state.parser.(IO.iodata_to_binary(state.body))]
      end

    state = %{state | body: [], demand: state.demand - 1}

    if events == [] or state.demand > 0 do
      # if there's more demand or we got a cached response, try again later
      Process.send_after(self(), :fetch, state.fetch_after)
    end

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
end
