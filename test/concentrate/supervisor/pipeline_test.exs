defmodule Concentrate.Supervisor.PipelineTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Supervisor.Pipeline

  describe "children/1" do
    test "builds the right number of children" do
      # currently, the right number is 899 (2 urls + 1 merge/filter + 1 group
      # encoder + 2 encoders + 1 sink + 1 reporter + file tap)
      config = [
        sources: [
          gtfs_realtime: [
            name: "url",
            name2: {"url2", fallback_url: "url fallback"}
          ]
        ],
        reporters: [Concentrate.Reporter.VehicleLatency],
        encoders: [files: [{"filename", :module}, {"other_file", :other_mod}]],
        sinks: [filesystem: [directory: "/tmp"]]
      ]

      actual = children(config)

      assert length(actual) == 9
    end

    test "s3 sink generates a child for each source and output" do
      config = [
        sources: [
          gtfs_realtime: [
            name: "url",
            name2: {"url2", fallback_url: "url fallback"}
          ],
          gtfs_realtime_enhanced: [
            name3: "url3"
          ]
        ],
        reporters: [],
        encoders: [files: [{"filename", :module}, {"other_file", :other_mod}]],
        sinks: [s3: []],
        file_tap: [
          enabled?: true
        ]
      ]

      source_count =
        length(config[:sources][:gtfs_realtime]) +
          length(config[:sources][:gtfs_realtime_enhanced])

      encoder_count = length(config[:encoders][:files])
      sink_count = source_count + encoder_count + 1

      actual = children(config)
      # extra 3 are MergeFilter, FileTap, and GroupProducerConsumer
      assert length(actual) == source_count + 3 + encoder_count + sink_count
    end
  end
end
