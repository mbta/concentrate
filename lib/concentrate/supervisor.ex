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

    Supervisor.start_link(children(config), strategy: :one_for_one)
  end

  def children(config) do
    {source_names, source_children} = sources(config[:sources])
    {output_names, output_children} = encoders(config[:encoders])
    merge = merge(source_names)
    filter = filter(config[:filters])
    sinks = sinks(config[:sinks], output_names)
    Enum.concat([source_children, merge, filter, output_children, sinks])
  end

  def sources(config) do
    children =
      for {source, url} <- config[:gtfs_realtime] do
        child_spec(
          {
            Concentrate.Producer.HTTP,
            {url, name: source, parser: Concentrate.Parser.GTFSRealtime}
          },
          id: source
        )
      end

    {child_ids(children), children}
  end

  def merge(source_names) do
    [
      {Concentrate.Merge.ProducerConsumer, name: :merge, subscribe_to: source_names}
    ]
  end

  def filter(config) do
    [
      {
        Concentrate.Filter.ProducerConsumer,
        name: :filter, filters: config, subscribe_to: [:merge]
      }
    ]
  end

  def encoders(config) do
    children =
      for {filename, encoder} <- config[:files] do
        child_spec(
          {
            Concentrate.Encoder.ProducerConsumer,
            name: encoder, files: [{filename, encoder}], subscribe_to: [:filter]
          },
          id: encoder
        )
      end

    {child_ids(children), children}
  end

  def sinks(config, output_names) do
    [
      {Concentrate.Sink.Filesystem, [
        directory: config[:filesystem][:directory],
        subscribe_to: output_names
      ]}
    ]
  end

  defp child_ids(children) do
    for child <- children, do: child.id
  end
end
