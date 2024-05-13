defmodule Concentrate.Parser.SignsConfigTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Parser.SignsConfig
  import Concentrate.TestHelpers

  describe "parse/1" do
    test "parses a json feed" do
      body = File.read!(fixture_path("signs_config.json"))

      assert [%{route_id: "Green-D", direction_id: 1, stop_id: "70180"} | _] = parse(body, [])
    end

    test "returns empty list if missing stops key" do
      body = File.read!(fixture_path("signs_config.json"))
      body = Jason.decode!(body)
      body = Map.get(body, "stops")
      body = Jason.encode!(body)

      assert [] = parse(body, [])
    end
  end
end
