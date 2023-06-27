defmodule Concentrate.Parser.AlertsTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Parser.Alerts
  import Concentrate.TestHelpers

  describe "parse/1" do
    test "parses a protobuf file" do
      body = File.read!(fixture_path("alerts.pb"))
      assert [_ | _] = parse(body, [])
    end

    test "parses a JSON file" do
      body = File.read!(fixture_path("alerts_enhanced.json"))
      assert [_ | _] = parse(body, [])
    end

    test "ignores alerts with closed_timestamp property, json payload" do
      body = File.read!(fixture_path("alerts_enhanced_closed.json"))
      result = parse(body, [])
      assert result == []
    end
  end
end
