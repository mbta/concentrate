defmodule Concentrate.Parser.ScreenplayConfig do
  @moduledoc """
  Parser for Screenplay predction suppresion API response.
  """
  @behaviour Concentrate.Parser

  @impl Concentrate.Parser
  def parse(binary, _opts) when is_binary(binary) do
    binary
    |> Jason.decode!(strings: :copy)
    |> map_entities()
  end

  defp map_entities(items) do
    items
    |> Enum.filter(fn i -> Map.get(i, "suppression_type") != "none" end)
    |> Enum.map(fn i ->
      %{
        route_id: Map.get(i, "route_id"),
        direction_id: Map.get(i, "direction_id"),
        stop_id: Map.get(i, "stop_id"),
        suppression_type: Map.get(i, "suppression_type")
      }
    end)
  end
end
