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

  defp decode_json_key_value(_unknown) do
    []
  end

  defp decode_gtfs_realtime(realtime) do
    # UNSAFE! only call this during startup, and with controlled JSON files.
    for {key, value} <- realtime, into: %{} do
      value =
        case value do
          %{url: url, routes: routes} when is_list(routes) ->
            {url, routes: routes}

          %{url: url} when is_binary(url) ->
            url

          url when is_binary(url) ->
            url
        end

      {key, value}
    end
  end

  defp update_configuration({key, value}) do
    Application.put_env(:concentrate, key, value)
  end
end
