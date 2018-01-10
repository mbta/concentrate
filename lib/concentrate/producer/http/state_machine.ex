defmodule Concentrate.Producer.HTTP.StateMachine do
  @moduledoc """
  State machine to manage the incoming/outgoing messages for making recurring HTTP requests.
  """
  require Logger

  defstruct url: "",
            get_opts: [],
            body: "",
            headers: [],
            ref: nil,
            fetch_after: 5_000,
            content_warning_timeout: 300_000,
            last_success: nil,
            previous_hash: -1

  @type t :: %__MODULE__{url: binary}
  @type message :: {term, non_neg_integer}
  @type return :: {t, [binary], [message]}

  @spec init(binary, Keyword.t()) :: t
  def init(url, opts) when is_binary(url) and is_list(opts) do
    state = %__MODULE__{url: url}
    state = struct!(state, Keyword.take(opts, ~w(get_opts fetch_after content_warning_timeout)a))
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

  defp handle_message(%{ref: nil} = machine, {:fetch, url}) do
    case HTTPoison.get(url, machine.headers, [stream_to: self()] ++ machine.get_opts) do
      {:ok, %{id: ref}} ->
        {%{machine | ref: ref}, [], []}

      {:error, error} ->
        handle_message(machine, error)
    end
  end

  defp handle_message(%{ref: ref} = machine, %HTTPoison.AsyncStatus{id: ref, code: 200}) do
    {machine, [], []}
  end

  defp handle_message(%{ref: ref} = machine, %HTTPoison.AsyncStatus{id: ref, code: 301}) do
    machine = %{machine | body: {:redirect, :permanent}}
    {machine, [], []}
  end

  defp handle_message(%{ref: ref} = machine, %HTTPoison.AsyncStatus{id: ref, code: 302}) do
    machine = %{machine | body: {:redirect, :temporary}}
    {machine, [], []}
  end

  defp handle_message(%{ref: ref} = machine, %HTTPoison.AsyncStatus{id: ref, code: 304}) do
    Logger.info(fn ->
      "#{__MODULE__}: #{inspect(machine.url)} not modified"
    end)

    machine = %{machine | body: :halt}
    {machine, [], []}
  end

  defp handle_message(%{ref: ref} = machine, %HTTPoison.AsyncStatus{id: ref, code: code}) do
    Logger.warn(fn ->
      "#{__MODULE__}: #{inspect(machine.url)} unexpected code #{inspect(code)}"
    end)

    machine = %{machine | body: :halt}
    {machine, [], []}
  end

  defp handle_message(%{ref: ref, body: :halt} = machine, %HTTPoison.AsyncHeaders{id: ref}) do
    {machine, [], []}
  end

  defp handle_message(%{ref: ref, body: {:redirect, type}} = machine, %HTTPoison.AsyncHeaders{
         id: ref,
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

  defp handle_message(%{ref: ref} = machine, %HTTPoison.AsyncHeaders{
         id: ref,
         headers: resp_headers
       }) do
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

  defp handle_message(%{ref: ref, body: binary} = machine, %HTTPoison.AsyncChunk{
         id: ref,
         chunk: chunk
       })
       when is_binary(binary) do
    machine = %{machine | body: binary <> chunk}
    {machine, [], []}
  end

  defp handle_message(%{ref: ref} = machine, %HTTPoison.AsyncChunk{id: ref}) do
    {machine, [], []}
  end

  defp handle_message(%{ref: ref} = machine, %HTTPoison.Error{id: ref, reason: reason}) do
    log_level = error_log_level(reason)

    _ =
      Logger.log(log_level, fn ->
        "#{__MODULE__}: #{inspect(machine.url)} error: #{inspect(reason)}"
      end)

    message = fetch_message(machine)
    messages = [{message, delay_after_fetch(machine)}]
    machine = reset_machine(machine)
    {machine, [], messages}
  end

  defp handle_message(%{ref: ref} = machine, %HTTPoison.AsyncEnd{id: ref}) do
    {bodies, machine} = parse_bodies(machine)
    machine = check_last_success(machine, bodies)
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

  defp parse_bodies(%{body: body, previous_hash: previous_hash} = machine) when is_binary(body) do
    case :erlang.phash2(machine.body) do
      ^previous_hash ->
        Logger.info(fn ->
          "#{__MODULE__}: #{inspect(machine.url)} same content"
        end)

        {[], machine}

      new_hash ->
        {[body], %{machine | previous_hash: new_hash}}
    end
  end

  defp parse_bodies(machine) do
    {[], machine}
  end

  defp check_last_success(%{last_success: last_success} = machine, [])
       when is_integer(last_success) do
    time_since_last_success = now() - last_success

    if time_since_last_success > machine.content_warning_timeout do
      Logger.error(fn ->
        delay = div(time_since_last_success, 1000)
        "#{__MODULE__}: #{inspect(machine.url)} has not been updated in #{delay}s"
      end)

      %{machine | last_success: now()}
    else
      machine
    end
  end

  defp check_last_success(machine, _) do
    %{machine | last_success: now()}
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
    %{machine | body: "", ref: nil}
  end

  defp error_log_level(:closed), do: :warn
  defp error_log_level({:closed, _}), do: :warn
  defp error_log_level(_), do: :error

  defp now do
    System.monotonic_time(:millisecond)
  end
end
