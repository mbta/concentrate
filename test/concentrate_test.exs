defmodule ConcentrateTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate

  describe "parse_json_configuration/1" do
    test "nil return empty list" do
      assert parse_json_configuration(nil) == []
    end

    test "invalid JSON raises an exception" do
      assert_raise Jason.DecodeError, fn -> parse_json_configuration("{") end
    end

    test "parses config into a keyword list" do
      body = ~s(
{
  "sources": {
    "gtfs_realtime": {
      "name_1": "url_1",
      "name_2": "url_2"
    },
    "gtfs_realtime_enhanced": {
      "enhanced_1": "url_3"
    }
  },
  "gtfs": {
    "url": "gtfs_url"
  },
  "alerts": {
    "url": "alerts_url"
  },
  "sinks": {
    "s3": {
      "bucket": "s3-bucket",
      "prefix": "bucket_prefix"
    }
  }
}
      )
      config = parse_json_configuration(body)

      assert config[:sources][:gtfs_realtime] == %{
               name_1: "url_1",
               name_2: "url_2"
             }

      assert config[:sources][:gtfs_realtime_enhanced] == %{
               enhanced_1: "url_3"
             }

      assert config[:gtfs][:url] == "gtfs_url"
      assert config[:alerts][:url] == "alerts_url"
      assert config[:sinks][:s3][:bucket] == "s3-bucket"
      assert config[:sinks][:s3][:prefix] == "bucket_prefix"
    end

    test "missing keys aren't configured" do
      body = ~s(
        {
          "sources": {},
          "sinks": {}
        })
      config = parse_json_configuration(body)
      assert config[:sources][:gtfs_realtime] == %{}
      assert config[:sources][:gtfs_realtime_enhanced] == %{}
      assert config[:gtfs] == nil
      assert config[:sinks] == %{}
    end

    test "gtfs_realtime sources can have additional route configuration" do
      body = ~s(
{
  "sources": {
    "gtfs_realtime": {
      "name": {
        "url": "url",
        "routes": ["a", "b"]
      },
      "name_2": {
        "url": "only_url"
      }
    }
  }
})
      config = parse_json_configuration(body)
      assert config[:sources][:gtfs_realtime][:name] == {"url", routes: ~w(a b)}
      assert config[:sources][:gtfs_realtime][:name_2] == "only_url"
    end
  end
end
