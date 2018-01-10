defmodule Concentrate.Supervisor do
  @moduledoc """
  Supervisor for Concentrate.

  Children:
  * one per file we're fetching
  * one to merge multiple files into a single output stream
  * one to build output files (currently TripUpdates.pb and VehiclePositions.pb)
  * one to save files
  """
  import Supervisor, only: [child_spec: 2]

  def start_link do
    config = Application.get_all_env(:concentrate)

    Supervisor.start_link(children(config), strategy: :rest_for_one)
  end

  def children(config) do
    {source_names, source_children} = sources(config[:sources])
    {output_names, output_children} = encoders(config[:encoders])
    merge = merge(source_names)
    alerts = alerts(config[:alerts])
    gtfs = gtfs(config[:gtfs])
    filter = filter(config[:filters])
    sinks = sinks(config[:sinks], output_names)
    Enum.concat([source_children, merge, alerts, gtfs, filter, output_children, sinks])
  end

  def sources(config) do
    realtime_children =
      for {source, url} <- config[:gtfs_realtime] || [] do
        {url, parser} =
          case url do
            {url, opts} ->
              {url, {Concentrate.Parser.GTFSRealtime, opts}}

            url ->
              {url, Concentrate.Parser.GTFSRealtime}
          end

        child_spec(
          {
            Concentrate.Producer.HTTP,
            {url, name: source, parser: parser}
          },
          id: source
        )
      end

    enhanced_children =
      for {source, url} <- config[:gtfs_realtime_enhanced] || [] do
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

  def merge(source_names) do
    sources = outputs_with_options(source_names, max_demand: 1)

    [
      {
        Concentrate.Merge.ProducerConsumer,
        name: :merge, subscribe_to: sources, buffer_size: 1
      }
    ]
  end

  def alerts(config) do
    [
      {Concentrate.Filter.Alert.Supervisor, config}
    ]
  end

  def gtfs(config) do
    [
      {Concentrate.Filter.GTFS.Supervisor, config}
    ]
  end

  def filter(config) do
    [
      {
        Concentrate.Filter.ProducerConsumer,
        name: :filter, filters: config, buffer_size: 1, subscribe_to: [merge: [max_demand: 1]]
      }
    ]
  end

  def encoders(config) do
    children =
      for {filename, encoder} <- config[:files] do
        child_spec(
          {
            Concentrate.Encoder.ProducerConsumer,
            name: encoder,
            files: [{filename, encoder}],
            subscribe_to: [filter: [max_demand: 1]],
            buffer_size: 1
          },
          id: encoder
        )
      end

    {child_ids(children), children}
  end

  def sinks(config, output_names) do
    for {sink_type, sink_config} <- config do
      sink_config(sink_type, sink_config, output_names)
    end
  end

  defp sink_config(:filesystem, config, output_names) do
    {Concentrate.Sink.Filesystem, [
      directory: config[:directory],
      subscribe_to: output_names
    ]}
  end

  defp sink_config(:s3, config, output_names) do
    {Concentrate.Sink.S3, [subscribe_to: output_names] ++ config}
  end

  defp sink_config(:visualize, config, output_names) do
    selector = fn {filename, _} ->
      Path.extname(filename) == ".pb"
    end

    outputs = outputs_with_options(output_names, selector: selector)
    {Concentrate.Sink.GTFSRealtimeViz, [subscribe_to: outputs] ++ config}
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
