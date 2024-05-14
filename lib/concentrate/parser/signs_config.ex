defmodule Concentrate.Parser.SignsConfig do
  @moduledoc """
  Parser for signs config predction suppresion feed.
  """
  @behaviour Concentrate.Parser

  @impl Concentrate.Parser
  def parse(binary, _opts) when is_binary(binary) do
    binary
    |> Jason.decode!(strings: :copy)
    |> map_entities()
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
