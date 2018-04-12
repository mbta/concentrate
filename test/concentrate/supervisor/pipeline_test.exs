defmodule Concentrate.Supervisor.PipelineTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Supervisor.Pipeline

  describe "children/1" do
    test "builds the right number of children" do
      # currently, the right number is 8 (2 urls + 1 merge/filter/grouper +
      # 2 encoders + 1 sink supervisor + 1 reporter + file tap)
      config = [
        sources: [
          gtfs_realtime: [
            name: "url",
            name2:
              {"url2",
               fallback_url: "url fallback",
               routes: ["1"],
               excluded_routes: ["2"],
               max_future_time: 3600}
          ]
        ],
        reporters: [Concentrate.Reporter.VehicleLatency],
        encoders: [files: [{"filename", :module}, {"other_file", :other_mod}]],
        sinks: [filesystem: [directory: "/tmp"]]
      ]

      actual = children(config)

      assert length(actual) == 8
    end

    test "correctly passes parse options to the parser" do
      config = [
        sources: [
          gtfs_realtime: [
            name:
              {"url",
               fallback_url: "url fallback",
               routes: ["1"],
               excluded_routes: ["2"],
               max_future_time: 3600}
          ]
        ],
        reporters: [],
        encoders: [files: []],
        sinks: []
      ]

      [url_child | _] = children(config)

      assert {_, _, [{"url", url_opts}]} = url_child.start

      assert url_opts[:parser] == {
               Concentrate.Parser.GTFSRealtime,
               [
                 routes: ~w(1),
                 excluded_routes: ~w(2),
                 max_future_time: 3600
               ]
             }
    end
  end
end
