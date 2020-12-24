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
      "name_2": {
        "url": "url_2",
        "fallback_url": "url_fallback"
      },
      "name_3": {
        "url": "url_3",
        "routes": ["a", "b"]
      },
      "name_4": {
        "url": "url_4",
        "max_future_time": 3600
      },
      "name_5": {
        "url": "url_5",
        "content_warning_timeout": 3600
      },
      "name_6": {
        "url": "url_6",
        "headers": {
          "Authorization": "auth"
        }
      },
      "name_7": {
        "url": "url_7",
        "drop_fields": {
          "VehiclePosition": ["speed"]
        }
      }
    },
    "gtfs_realtime_enhanced": {
      "enhanced_1": {
        "url": "url_3",
        "drop_fields": {
          "TripDescriptor": ["start_time"]
        }
      }
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
      "prefix": "bucket_prefix",
      "ignored": "value"
    }
  },
  "file_tap": {
    "enabled": true
  }
}
      )
      config = parse_json_configuration(body)

      assert config[:sources][:gtfs_realtime] == %{
               name_1: "url_1",
               name_2: {"url_2", fallback_url: "url_fallback"},
               name_3: {"url_3", routes: ~w(a b)},
               name_4: {"url_4", max_future_time: 3600},
               name_5: {"url_5", content_warning_timeout: 3600},
               name_6: {"url_6", headers: %{"Authorization" => "auth"}},
               name_7: {"url_7", drop_fields: %{Concentrate.VehiclePosition => [:speed]}}
             }

      assert config[:sources][:gtfs_realtime_enhanced] == %{
               enhanced_1: {"url_3", drop_fields: %{Concentrate.TripDescriptor => [:start_time]}}
             }

      assert config[:gtfs][:url] == "gtfs_url"
      assert config[:alerts][:url] == "alerts_url"
      assert config[:sinks][:s3][:bucket] == "s3-bucket"
      assert config[:sinks][:s3][:prefix] == "bucket_prefix"
      assert is_list(config[:sinks][:s3])
      assert config[:file_tap][:enabled?]
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

    test "log_level sets Logger.level" do
      old_level = Logger.level()

      on_exit(fn ->
        Logger.configure(level: old_level)
      end)

      body = ~s({"log_level": "info"})
      _ = parse_json_configuration(body)
      assert Logger.level() == :info

      body = ~s({"log_level": "debug"})
      _ = parse_json_configuration(body)
      assert Logger.level() == :debug
    end

    test "parses sources with system environment variables" do
      env_var = "CONCENTRATE_TEST_ENV_VAR"
      env_var_value = "secret_key"
      body = ~s(
{
  "sources": {
    "gtfs_realtime": {
      "name_1": {
        "url": "url_1",
        "headers": {
          "Authorization": {"system": "#{env_var}"}
        }
      }
    }
  }
}
      )
      System.put_env(env_var, env_var_value)

      try do
        config = parse_json_configuration(body)

        assert config[:sources][:gtfs_realtime][:name_1] ==
                 {"url_1", [headers: %{"Authorization" => "secret_key"}]}
      after
        System.delete_env(env_var)
      end
    end
  end
end
