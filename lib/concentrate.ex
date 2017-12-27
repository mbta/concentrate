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
    json = Poison.decode!(json)
    Enum.flat_map(json, &decode_json_key_value/1)
  end

  defp decode_json_key_value({"sources", source_object}) do
    realtime = source_object["gtfs_realtime"] || %{}
    enhanced = source_object["gtfs_realtime_enhanced"] || %{}

    [
      sources: [
        gtfs_realtime: atomize_keys(realtime),
        gtfs_realtime_enhanced: atomize_keys(enhanced)
      ]
    ]
  end

  defp decode_json_key_value({"gtfs", object}) do
    if url = object["url"] do
      [gtfs: [url: url]]
    else
      []
    end
  end

  defp decode_json_key_value({"sinks", sinks_object}) do
    sinks =
      if s3_object = sinks_object["s3"] do
        %{
          s3: [
            bucket: s3_object["bucket"],
            prefix: s3_object["prefix"]
          ]
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

  defp atomize_keys(enumerable) do
    # UNSAFE! only call this during startup, and with controlled JSON files.
    for {key, value} <- enumerable, into: %{} do
      {String.to_atom(key), value}
    end
  end

  defp update_configuration({key, value}) do
    Application.put_env(:concentrate, key, value)
  end
end
