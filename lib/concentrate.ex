defmodule Concentrate do
  @moduledoc """
  Application entry point for Concentrate
  """
  use Application

  def start(_type, _args) do
    "CONCENTRATE_JSON"
    |> System.get_env()
    |> parse_json_configuration
    |> Enum.each(&update_configuration/1)

    Concentrate.Supervisor.start_link()
  end

  def parse_json_configuration(nil) do
    []
  end

  def parse_json_configuration(json) do
    json = Jason.decode!(json, strings: :copy)
    Enum.flat_map(json, &decode_json_key_value/1)
  end

  @doc """
  Unwraps a value which is optionally wrapped in a 0-arity function.

  This wrapping is done with environment secrets, to avoid logging them.
  """
  def unwrap(value) when is_function(value, 0) do
    value.()
  end

  def unwrap(value) do
    value
  end

  @doc """
  Unwraps the values of a keyword list or map.
  """
  def unwrap_values(opts) when is_list(opts) do
    for {key, value} <- opts do
      {key, unwrap(value)}
    end
  end

  def unwrap_values(opts) when is_map(opts) do
    for {key, value} <- opts, into: %{} do
      {key, unwrap(value)}
    end
  end

  @doc """
  Returns a Concentrate.Producer for the given URL.
  """
  def producer_for_url(url) do
    %URI{scheme: scheme} = URI.parse(url)
    scheme_producers = Application.get_env(:concentrate, :scheme_producers)
    Map.fetch!(scheme_producers, scheme)
  end

  defp decode_json_key_value({"sources", source_object}) do
    realtime = Map.get(source_object, "gtfs_realtime", %{})
    enhanced = Map.get(source_object, "gtfs_realtime_enhanced", %{})

    [
      sources: [
        gtfs_realtime: decode_gtfs_realtime(realtime),
        gtfs_realtime_enhanced: decode_gtfs_realtime(enhanced)
      ]
    ]
  end

  defp decode_json_key_value({"alerts", object}) do
    case object do
      %{"url" => url} ->
        [alerts: [url: url]]

      _ ->
        []
    end
  end

  defp decode_json_key_value({"gtfs", %{"url" => url}}) do
    [gtfs: [url: url]]
  end

  defp decode_json_key_value({"signs_stops_config", %{"url" => url}}) do
    [signs_stops_config: [url: url]]
  end

  defp decode_json_key_value({"sinks", sinks_object}) do
    sinks = decode_sinks_object(sinks_object, %{})

    [
      sinks: sinks
    ]
  end

  defp decode_json_key_value({"log_level", level_str}) do
    level =
      case level_str do
        "error" -> :error
        "warn" -> :warning
        "warning" -> :warning
        "info" -> :info
        "debug" -> :debug
      end

    Logger.configure(level: level)
    []
  end

  defp decode_json_key_value({"file_tap", opts}) do
    if Map.get(opts, "enabled") do
      sink_opts =
        case opts do
          %{"sinks" => sinks} when is_list(sinks) ->
            [sinks: Enum.map(sinks, &String.to_existing_atom/1)]

          _ ->
            []
        end

      [file_tap: [enabled?: true] ++ sink_opts]
    else
      []
    end
  end

  defp decode_json_key_value(_unknown) do
    []
  end

  defp decode_gtfs_realtime(realtime) do
    # UNSAFE! only call this during startup, and with controlled JSON files.
    for {key, value} <- realtime, into: %{} do
      value = decode_gtfs_realtime_value(value)
      {String.to_atom(key), value}
    end
  end

  defp decode_gtfs_realtime_value(url) when is_binary(url) do
    url
  end

  defp decode_gtfs_realtime_value(%{"url" => url} = value) when is_binary(url) do
    opts =
      for {key, {guard, process}} <- [
            routes: {&is_list/1, & &1},
            excluded_routes: {&is_list/1, & &1},
            fallback_url: {&is_binary/1, & &1},
            username: {&possible_env_var?/1, &process_possible_env_var/1},
            password: {&possible_env_var?/1, &process_possible_env_var/1},
            topics: {&is_list/1, & &1},
            max_future_time: {&is_integer/1, & &1},
            fetch_after: {&is_integer/1, & &1},
            content_warning_timeout: {&is_integer/1, & &1},
            headers: {&is_map/1, &process_headers/1},
            drop_fields: {&is_map/1, &process_drop_fields/1}
          ],
          {:ok, opt_value} <- [Map.fetch(value, Atom.to_string(key))],
          guard.(opt_value) do
        {key, process.(opt_value)}
      end

    if opts == [] do
      url
    else
      {url, opts}
    end
  end

  defp decode_sinks_object(%{"s3" => s3_object} = sinks_object, acc) do
    acc = Map.put(acc, :s3, decode_s3(s3_object))

    sinks_object
    |> Map.delete("s3")
    |> decode_sinks_object(acc)
  end

  defp decode_sinks_object(%{"mqtt" => mqtt_object} = sinks_object, acc) do
    acc = Map.put(acc, :mqtt, decode_mqtt(mqtt_object))

    sinks_object
    |> Map.delete("mqtt")
    |> decode_sinks_object(acc)
  end

  defp decode_sinks_object(_, acc) do
    Keyword.new(acc)
  end

  defp possible_env_var?(value) do
    case value do
      %{"system" => _} -> true
      <<_::binary>> -> true
      _ -> false
    end
  end

  defp process_possible_env_var(%{"system" => env_var}) do
    fn -> System.get_env(env_var) end
  end

  defp process_possible_env_var(raw_value) when is_binary(raw_value) do
    raw_value
  end

  defp process_headers(map) do
    for {key, raw_value} <- map, into: %{} do
      {key, process_possible_env_var(raw_value)}
    end
  end

  defp process_drop_fields(map) do
    for {mod_suffix, str_fields} <- map, into: %{} do
      mod = Module.concat(["Concentrate", mod_suffix])
      fields = Enum.map(str_fields, &String.to_existing_atom/1)
      {mod, fields}
    end
  end

  defp decode_s3(s3_object) do
    keys = ~w(bucket prefix)a

    Enum.reduce(keys, [], fn key, acc ->
      key_str = Atom.to_string(key)

      case s3_object do
        %{^key_str => value} ->
          [{key, value} | acc]

        _ ->
          acc
      end
    end)
  end

  defp decode_mqtt(mqtt_object) do
    keys = ~w(url prefix username password)a

    Enum.reduce(keys, [], fn key, acc ->
      case Map.fetch(mqtt_object, Atom.to_string(key)) do
        {:ok, value} ->
          [{key, process_possible_env_var(value)} | acc]

        :error ->
          acc
      end
    end)
  end

  defp update_configuration({key, value}) do
    Application.put_env(:concentrate, key, value)
  end
end
