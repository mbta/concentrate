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
        source_reporters: [Concentrate.SourceReporter.Latency],
        reporters: [Concentrate.Reporter.VehicleLatency],
        encoders: [files: [{"filename", :module}, {"other_file", :other_mod}]],
        sinks: [filesystem: [directory: "/tmp"]]
      ]

      actual = children(config)

      assert length(actual) == 8
    end

    test "enables file_tap with all sinks by default" do
      config = [
        sources: [],
        source_reporters: [],
        reporters: [],
        encoders: [files: [{"filename", :encoder_module}]],
        sinks: [filesystem: [directory: "/tmp"]],
        file_tap: [enabled?: true]
      ]

      actual = children(config)

      assert Concentrate.Producer.FileTap in actual

      assert {Concentrate.Sink.Supervisor,
              [config: [filesystem: _], sources: [Concentrate.Producer.FileTap, :encoder_module]]} =
               List.keyfind(actual, Concentrate.Sink.Supervisor, 0)
    end

    test "enables file_tap with some sinks if configured" do
      config = [
        sources: [],
        source_reporters: [],
        reporters: [],
        encoders: [files: [{"filename", :encoder_module}]],
        sinks: [filesystem: [directory: "/tmp"], s3: []],
        file_tap: [enabled?: true, sinks: [:filesystem]]
      ]

      actual = children(config)

      assert Concentrate.Producer.FileTap in actual

      # file tap sinks get an ID to avoid duplication
      assert [
               %{
                 id: _,
                 start:
                   {Concentrate.Sink.Supervisor, :start_link,
                    [
                      [filesystem: _],
                      [Concentrate.Producer.FileTap, :encoder_module]
                    ]}
               }
             ] =
               Enum.filter(actual, fn value ->
                 match?(%{start: {Concentrate.Sink.Supervisor, _, _}}, value)
               end)

      # non-file tap sinks
      assert [
               {Concentrate.Sink.Supervisor, [config: [s3: _], sources: [:encoder_module]]}
             ] =
               Enum.filter(actual, fn value -> match?({Concentrate.Sink.Supervisor, _}, value) end)
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
        source_reporters: [],
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
