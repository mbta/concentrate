defmodule Concentrate.Producer.HTTP do
  @moduledoc """
  GenStage Producer which fulfills demand by fetching from an HTTP Server.
  """
  use GenStage
  alias Concentrate.Producer.HTTP.StateMachine, as: SM
  require Logger
  @start_link_opts [:name]

  defmodule State do
    @moduledoc """
    Module for keeping track of the state for an HTTP producer.
    """
    defstruct [:machine, :parser, demand: 0]
  end

  alias __MODULE__.State

  def start_link({url, opts}) when is_binary(url) and is_list(opts) do
    start_link_opts = Keyword.take(opts, @start_link_opts)
    opts = Keyword.drop(opts, @start_link_opts)
    GenStage.start_link(__MODULE__, {url, opts}, start_link_opts)
  end

  @impl GenStage
  def init({url, opts}) do
    parser =
      case Keyword.get(opts, :parser) do
        module when is_atom(module) ->
          fn binary -> module.parse(binary, []) end

        {module, opts} when is_atom(module) and is_list(opts) ->
          fn binary -> module.parse(binary, opts) end

        fun when is_function(fun, 1) ->
          fun
      end

    opts = Keyword.drop(opts, [:parser])
    machine = SM.init(url, opts)

    {
      :producer,
      %State{machine: machine, parser: parser},
      dispatcher: GenStage.BroadcastDispatcher
    }
  end

  @impl GenStage
  def handle_info(message, %{machine: machine, demand: demand} = state) do
    {machine, bodies, outgoing_messages} = SM.message(machine, message)
    events = parse_bodies(bodies, state)
    new_demand = demand - length(events)

    if new_demand > 0 do
      send_outgoing_messages(outgoing_messages)
    end

    new_state = %{state | machine: machine, demand: new_demand}

    if events == [] do
      {:noreply, events, new_state}
    else
      {:noreply, events, new_state, :hibernate}
    end
  end

  @impl GenStage
  def handle_demand(new_demand, %{machine: machine, demand: existing_demand} = state) do
    {machine, [], outgoing_messages} = SM.fetch(machine)

    if existing_demand == 0 do
      send_outgoing_messages(outgoing_messages)
    end

    {:noreply, [], %{state | machine: machine, demand: new_demand + existing_demand}}
  end

  defp parse_bodies([], _state) do
    []
  end

  defp parse_bodies([binary], state) do
    {time, parsed} = :timer.tc(state.parser, [binary])

    Logger.info(fn ->
      "#{__MODULE__}: #{inspect(state.machine.url)} got #{length(parsed)} records in #{
        time / 1000
      }ms"
    end)

    [parsed]
  rescue
    error -> parse_error(error, state, System.stacktrace())
  catch
    error -> parse_error(error, state, System.stacktrace())
  end

  defp parse_error(error, state, trace) do
    Logger.error(fn ->
      "#{__MODULE__}: #{inspect(state.machine.url)} parse error: #{inspect(error)}\n#{
        Exception.format_stacktrace(trace)
      }"
    end)

    []
  end

  defp send_outgoing_messages(outgoing_messages) do
    for {message, send_after} <- outgoing_messages do
      Process.send_after(self(), message, send_after)
    end
  end
end
