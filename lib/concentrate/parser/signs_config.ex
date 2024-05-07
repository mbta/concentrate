defmodule Concentrate.Parser.SignsConfig do
  @moduledoc """
  Parser for signs config predction suppresion feed.
  """
  @behaviour Concentrate.Parser

  @impl Concentrate.Parser
  def parse(binary, opts) when is_binary(binary) and is_list(opts) do
    json = Jason.decode!(binary, strings: :copy)
    map_entities(json)
  end

  defp map_entities(%{"stops" => items}) do
    items
    |> Enum.filter(fn i -> Map.get(i, "predictions") == "flagged" end)
    |> Enum.map(fn i ->
      %{
        route_id: Map.get(i, "route_id"),
        direction_id: Map.get(i, "direction_id"),
        stop_id: Map.get(i, "stop_id")
      }
    end)
  end

  defp map_entities(_), do: []
end
