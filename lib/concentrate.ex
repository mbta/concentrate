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
    json = Jason.decode!(json, keys: :atoms, strings: :copy)
    Enum.flat_map(json, &decode_json_key_value/1)
  end

  defp decode_json_key_value({:sources, source_object}) do
    realtime = Map.get(source_object, :gtfs_realtime, %{})
    enhanced = Map.get(source_object, :gtfs_realtime_enhanced, %{})

    [
      sources: [
        gtfs_realtime: decode_gtfs_realtime(realtime),
        gtfs_realtime_enhanced: enhanced
      ]
    ]
  end

  defp decode_json_key_value({:alerts, object}) do
    if url = object[:url] do
      [alerts: [url: url]]
    else
      []
    end
  end

  defp decode_json_key_value({:gtfs, %{url: url}}) do
    [gtfs: [url: url]]
  end

  defp decode_json_key_value({:sinks, sinks_object}) do
    sinks =
      if s3_object = sinks_object[:s3] do
        %{
          s3: Enum.to_list(s3_object)
        }
      else
        %{}
      end

    [
      sinks: sinks
    ]
  end

  defp decode_json_key_value({:log_level, level}) do
    # UNSAFE!
    Logger.configure(level: String.to_atom(level))
    []
  end

  defp decode_json_key_value(_unknown) do
    []
  end

  defp decode_gtfs_realtime(realtime) do
    # UNSAFE! only call this during startup, and with controlled JSON files.
    for {key, value} <- realtime, into: %{} do
      value = decode_gtfs_realtime_value(value)
      {key, value}
    end
  end

  defp decode_gtfs_realtime_value(url) when is_binary(url) do
    url
  end

  defp decode_gtfs_realtime_value(%{url: url} = value) when is_binary(url) do
    opts =
      for {key, guard} <- [
            routes: &is_list/1,
            fallback_url: &is_binary/1,
            max_future_time: &is_integer/1
          ],
          {:ok, opt_value} <- [Map.fetch(value, key)],
          guard.(opt_value) do
        {key, opt_value}
      end

    if opts == [] do
      url
    else
      {url, opts}
    end
  end

  defp update_configuration({key, value}) do
    Application.put_env(:concentrate, key, value)
  end
end
