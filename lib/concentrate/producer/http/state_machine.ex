defmodule Concentrate.Producer.HTTP.StateMachine do
  @moduledoc """
  State machine to manage the incoming/outgoing messages for making recurring HTTP requests.
  """
  require Logger
  @default_timeout 15_000

  defstruct url: "",
            get_opts: [timeout: @default_timeout, recv_timeout: @default_timeout],
            headers: [],
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
    {machine, [], [{{:fetch, machine.url}, fetch_delay(machine)}]}
  end

  defp fetch_delay(%{last_success: nil}) do
    0
  end

  defp fetch_delay(machine) do
    since_last_success = now() - machine.last_success

    time =
      if since_last_success > machine.fetch_after do
        0
      else
        machine.fetch_after - since_last_success
      end

    Logger.debug(fn ->
      "#{__MODULE__} #{inspect(machine.url)} scheduling fetch after #{time}ms"
    end)

    time
  end

  @spec message(t, term) :: return
  def message(%__MODULE__{} = machine, message) do
    {machine, bodies, messages} = handle_message(machine, message)
    {machine, bodies, messages}
  end

  defp handle_message(machine, {:fetch, url}) do
    case HTTPoison.get(url, machine.headers, machine.get_opts) do
      {:ok, %HTTPoison.Response{} = response} ->
        handle_message(machine, {:http_response, response})

      {:error, %HTTPoison.Error{reason: reason}} ->
        handle_message(machine, {:http_error, reason})
    end
  end

  defp handle_message(
         machine,
         {:http_response, %{status_code: 200, headers: headers, body: body}}
       ) do
    {bodies, machine} = parse_bodies(machine, body)
    machine = update_cache_headers(machine, headers)
    machine = check_last_success(machine)
    message = {:fetch, machine.url}
    messages = [{message, machine.fetch_after}]

    {machine, bodies, messages}
  end

  defp handle_message(machine, {:http_response, %{status_code: 301, headers: headers}}) do
    # permanent redirect: save the new URL
    new_url = find_header(headers, "location")
    machine = %{machine | url: new_url}
    machine = check_last_success(machine)
    message = {:fetch, new_url}
    messages = [{message, 0}]
    {machine, [], messages}
  end

  defp handle_message(machine, {:http_response, %{status_code: 302, headers: headers}}) do
    # temporary redirect: request the new URL but don't save it
    new_url = find_header(headers, "location")
    machine = check_last_success(machine)
    message = {:fetch, new_url}
    messages = [{message, 0}]
    {machine, [], messages}
  end

  defp handle_message(machine, {:http_response, %{status_code: 304}}) do
    # not modified
    Logger.info(fn ->
      "#{__MODULE__}: #{inspect(machine.url)} not modified"
    end)

    machine = check_last_success(machine)
    message = {:fetch, machine.url}
    messages = [{message, machine.fetch_after}]
    {machine, [], messages}
  end

  defp handle_message(machine, {:http_response, %{status_code: code}}) do
    Logger.warn(fn ->
      "#{__MODULE__}: #{inspect(machine.url)} unexpected code #{inspect(code)}"
    end)

    machine = check_last_success(machine)
    message = {:fetch, machine.url}
    {machine, [], [{message, machine.fetch_after}]}
  end

  defp handle_message(machine, {:http_error, reason}) do
    log_level = error_log_level(reason)

    _ =
      Logger.log(log_level, fn ->
        "#{__MODULE__}: #{inspect(machine.url)} error: #{inspect(reason)}"
      end)

    machine = check_last_success(machine)
    message = {:fetch, machine.url}
    messages = [{message, machine.fetch_after}]
    {machine, [], messages}
  end

  defp handle_message(machine, unknown) do
    Logger.error(fn ->
      "#{__MODULE__}: #{inspect(machine.url)} got unexpected message: #{inspect(unknown)}"
    end)

    {machine, [], []}
  end

  defp find_header(headers, match_header) do
    {_, value} = Enum.find(headers, &(String.downcase(elem(&1, 0)) == match_header))
    value
  end

  defp update_cache_headers(machine, headers) do
    cache_headers =
      Enum.reduce(headers, [], fn {header, value}, acc ->
        cond do
          String.downcase(header) == "last-modified" ->
            [{:"if-modified-since", value} | acc]

          String.downcase(header) == "etag" ->
            [{:"if-none-match", value} | acc]

          true ->
            acc
        end
      end)

    %{machine | headers: cache_headers}
  end

  defp parse_bodies(%{previous_hash: previous_hash} = machine, body) do
    case :erlang.phash2(body) do
      ^previous_hash ->
        Logger.info(fn ->
          "#{__MODULE__}: #{inspect(machine.url)} same content"
        end)

        {[], machine}

      new_hash ->
        {[body], %{machine | previous_hash: new_hash, last_success: now()}}
    end
  end

  defp check_last_success(%{last_success: last_success} = machine)
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

  defp error_log_level(:timeout), do: :warn
  defp error_log_level(:timeout), do: :warn
  defp check_last_success(machine) do
    machine
  end

  defp error_log_level(:closed), do: :warn
  defp error_log_level({:closed, _}), do: :warn
  defp error_log_level(_), do: :error

  defp now do
    System.monotonic_time(:millisecond)
  end
end
