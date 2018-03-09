defmodule Concentrate.Supervisor.Pipeline do
  @moduledoc """
  Supervisor for the Concentrate pipeline.

  Children:
  * one per file we're fetching
  * one to merge multiple files into a single output stream
  * one per file to build output files
  * one per sink to save files
  """
  import Supervisor, only: [child_spec: 2]
  @buffer_size 2
  @max_demand 5

  def start_link(config) do
    Supervisor.start_link(children(config), strategy: :rest_for_one)
  end

  def children(config) do
    {source_names, source_children} = sources(config[:sources])
    {output_names, output_children} = encoders(config[:encoders])
    file_tap = [{Concentrate.Producer.FileTap, config[:file_tap]}]
    merge_filter = merge(source_names, config[:filters])
    reporters = reporters(config[:reporters])
    sinks = sinks(config[:sinks], [Concentrate.Producer.FileTap] ++ output_names, source_names)
    Enum.concat([source_children, file_tap, merge_filter, output_children, reporters, sinks])
  end

  def sources(config) do
    realtime_children =
      for {source, url} <- config[:gtfs_realtime] || [] do
        {url, opts, parser} =
          case url do
            {url, opts} when is_binary(url) ->
              {url, opts,
               {Concentrate.Parser.GTFSRealtime, Keyword.take(opts, ~w(routes max_future_time)a)}}

            url when is_binary(url) ->
              {url, [], Concentrate.Parser.GTFSRealtime}
          end

        child_spec(
          {
            Concentrate.Producer.HTTP,
            {url, [name: source, parser: parser] ++ opts}
          },
          id: source
        )
      end

    enhanced_children =
      for {source, url} when is_binary(url) <- config[:gtfs_realtime_enhanced] || [] do
        child_spec(
          {
            Concentrate.Producer.HTTP,
            {url, name: source, parser: Concentrate.Parser.GTFSRealtimeEnhanced}
          },
          id: source
        )
      end

    children = realtime_children ++ enhanced_children

    {child_ids(children), children}
  end

  def merge(source_names, filters) do
    sources = outputs_with_options(source_names, max_demand: @max_demand)

    [
      {
        Concentrate.MergeFilter,
        name: :merge_filter, subscribe_to: sources, buffer_size: @buffer_size, filters: filters
      }
    ]
  end

  def reporters(reporter_modules) when is_list(reporter_modules) do
    for module <- reporter_modules do
      child_spec(
        {Concentrate.Reporter.Consumer,
         module: module, subscribe_to: [merge_filter: [max_demand: @max_demand]]},
        id: module
      )
    end
  end

  def encoders(config) do
    group =
      {Concentrate.Encoder.GroupProducerConsumer,
       name: :group_pc,
       buffer_size: @buffer_size,
       subscribe_to: [merge_filter: [max_demand: @max_demand]]}

    children =
      for {filename, encoder} <- config[:files] do
        child_spec(
          {
            Concentrate.Encoder.ProducerConsumer,
            name: encoder,
            files: [{filename, encoder}],
            subscribe_to: [group_pc: [max_demand: @max_demand]],
            buffer_size: 1
          },
          id: encoder
        )
      end

    {child_ids(children), [group | children]}
  end

  def sinks(config, output_names, source_names) do
    for {sink_type, sink_config} <- config,
        child <- sink_config(sink_type, sink_config, output_names, source_names) do
      child
    end
  end

  defp sink_config(:filesystem, config, output_names, _source_names) do
    # filesystem gets serialized anyways, no point in running multiple workers
    [
      {Concentrate.Sink.Filesystem,
       [
         directory: config[:directory],
         subscribe_to: output_names
       ]}
    ]
  end

  defp sink_config(:s3, config, output_names, source_names) do
    # generate a sink per output name and source name, so that there's at
    # least a sink per file we're uploading
    count = length(output_names) + length(source_names)

    for id <- 1..count do
      child_spec(
        {Concentrate.Sink.S3, [subscribe_to: output_names] ++ config},
        id: {:s3_sink, id}
      )
    end
  end

  defp child_ids(children) do
    for child <- children, do: child.id
  end

  def outputs_with_options(outputs, options) do
    for name <- outputs do
      {name, options}
    end
  end
end
