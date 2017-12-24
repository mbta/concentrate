defmodule Concentrate.Producer.HTTP.StateMachine do
  @moduledoc """
  State machine to manage the incoming/outgoing messages for making recurring HTTP requests.
  """
  require Logger

  defstruct url: "",
            get_opts: [],
            body: [],
            headers: [],
            fetch_after: 5_000

  @type t :: %__MODULE__{url: binary}
  @type message :: {term, non_neg_integer}
  @type return :: {t, [binary], [message]}

  @spec init(binary, Keyword.t()) :: t
  def init(url, opts) when is_binary(url) and is_list(opts) do
    state = %__MODULE__{url: url}
    state = struct!(state, Keyword.take(opts, ~w(get_opts fetch_after)a))
    state
  end

  @spec fetch(t) :: return
  def fetch(%__MODULE__{} = machine) do
    {machine, [], [{fetch_message(machine), 0}]}
  end

  defp fetch_message(%{body: {:redirect, _, new_url}}) do
    {:fetch, new_url}
  end

  defp fetch_message(%{url: url}) do
    {:fetch, url}
  end

  @spec message(t, term) :: return
  def message(%__MODULE__{} = machine, message) do
    {machine, bodies, messages} = handle_message(machine, message)
    {machine, bodies, messages}
  end

  defp handle_message(machine, {:fetch, url}) do
    messages =
      case HTTPoison.get(url, machine.headers, [stream_to: self()] ++ machine.get_opts) do
        {:ok, _} ->
          []

        {:error, error} ->
          log_error(error, machine)
          [{fetch_message(machine), machine.fetch_after}]
      end

    {machine, [], messages}
  end

  defp handle_message(machine, %HTTPoison.AsyncStatus{code: 200}) do
    {machine, [], []}
  end

  defp handle_message(machine, %HTTPoison.AsyncStatus{code: 301}) do
    machine = %{machine | body: {:redirect, :permanent}}
    {machine, [], []}
  end

  defp handle_message(machine, %HTTPoison.AsyncStatus{code: 302}) do
    machine = %{machine | body: {:redirect, :temporary}}
    {machine, [], []}
  end

  defp handle_message(machine, %HTTPoison.AsyncStatus{code: 304}) do
    Logger.info(fn ->
      "#{__MODULE__}: #{inspect(machine.url)} not modified"
    end)

    machine = %{machine | body: :halt}
    {machine, [], []}
  end

  defp handle_message(machine, %HTTPoison.AsyncStatus{code: code}) do
    Logger.warn(fn ->
      "#{__MODULE__}: #{inspect(machine.url)} unexpected code #{inspect(code)}"
    end)

    machine = %{machine | body: :halt}
    {machine, [], []}
  end

  defp handle_message(%{body: :halt} = machine, %HTTPoison.AsyncHeaders{}) do
    {machine, [], []}
  end

  defp handle_message(%{body: {:redirect, type}} = machine, %HTTPoison.AsyncHeaders{
         headers: headers
       }) do
    {_, new_location} =
      Enum.find(headers, fn {header, _} -> String.downcase(header) == "location" end)

    machine =
      if type == :permanent do
        %{machine | url: new_location}
      else
        machine
      end

    machine = %{machine | body: {:redirect, type, new_location}}
    {machine, [], []}
  end

  defp handle_message(machine, %HTTPoison.AsyncHeaders{headers: resp_headers}) do
    # grab the cache headers
    headers =
      Enum.reduce(resp_headers, [], fn {header, value}, acc ->
        cond do
          String.downcase(header) == "last-modified" ->
            [{:"if-modified-since", value} | acc]

          String.downcase(header) == "etag" ->
            [{:"if-none-match", value} | acc]

          true ->
            acc
        end
      end)

    machine = %{machine | headers: headers}
    {machine, [], []}
  end

  defp handle_message(%{body: iolist} = machine, %HTTPoison.AsyncChunk{chunk: chunk})
       when is_list(iolist) do
    machine = %{machine | body: [iolist, chunk]}
    {machine, [], []}
  end

  defp handle_message(machine, %HTTPoison.AsyncChunk{}) do
    {machine, [], []}
  end

  defp handle_message(machine, %HTTPoison.Error{reason: reason}) do
    Logger.error(fn ->
      "#{__MODULE__}: #{inspect(machine.url)} error: #{inspect(reason)}"
    end)

    message = fetch_message(machine)
    messages = [{message, delay_after_fetch(machine)}]
    machine = reset_machine(machine)
    {machine, [], messages}
  end

  defp handle_message(machine, %HTTPoison.AsyncEnd{}) do
    bodies = parse_bodies(machine.body)
    delay = delay_after_fetch(machine)
    message = fetch_message(machine)
    messages = [{message, delay}]
    machine = reset_machine(machine)

    {machine, bodies, messages}
  end

  defp handle_message(machine, unknown) do
    Logger.error(fn ->
      "#{__MODULE__}: #{inspect(machine.url)} got unexpected message: #{inspect(unknown)}"
    end)

    {machine, [], []}
  end

  defp parse_bodies([_ | _] = body) do
    [IO.iodata_to_binary(body)]
  end

  defp parse_bodies(_) do
    []
  end

  defp delay_after_fetch(%{body: {:redirect, _, _}}) do
    # refetch immediately if we got redirected
    0
  end

  defp delay_after_fetch(%{fetch_after: fetch_after}) do
    # otherwise, schedule a fetch
    fetch_after
  end

  defp reset_machine(machine) do
    %{machine | body: []}
  end

  defp log_error(error, machine) do
    Logger.error(fn ->
      "#{__MODULE__}: #{inspect(machine.url)} fetch error: #{inspect(error)}"
    end)
  end
end
