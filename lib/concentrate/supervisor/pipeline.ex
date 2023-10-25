defmodule Concentrate.Supervisor.Pipeline do
  @moduledoc """
  Supervisor for the Concentrate pipeline.

  Children:
  * one per file we're fetching
  * one to merge multiple files into a single output stream
  * one per file to build output files
  * one supervisor sink to save files
  """
  import Supervisor, only: [child_spec: 2]

  def start_link(config) do
    Supervisor.start_link(children(config), strategy: :one_for_all)
  end

  def children(config) do
    {source_names, source_children} = sources(config[:sources])
    {output_names, output_children} = encoders(config[:encoders])
    merge_filter = merge(source_names, config)
    source_reporters = source_reporters(source_names, config[:source_reporters])
    reporters = reporters(config[:reporters])

    file_tap =
      if config[:file_tap][:enabled?] do
        [Concentrate.Producer.FileTap]
      else
        []
      end

    sinks =
      case config[:file_tap][:sinks] do
        nil when file_tap == [] ->
          [sink(config[:sinks], output_names)]

        nil ->
          # previous default
          [sink(config[:sinks], [Concentrate.Producer.FileTap | output_names])]

        file_tap_sink_ids ->
          {file_tap_sinks, non_file_tap_sinks} = Keyword.split(config[:sinks], file_tap_sink_ids)

          [
            Supervisor.child_spec(
              sink(file_tap_sinks, [Concentrate.Producer.FileTap] ++ output_names),
              id: :file_tap_sinks
            ),
            sink(non_file_tap_sinks, output_names)
          ]
      end

    Enum.concat([
      source_children,
      file_tap,
      merge_filter,
      output_children,
      source_reporters,
      reporters,
      sinks
    ])
  end

  def sources(config) do
    realtime_children = source_children(config, :gtfs_realtime, Concentrate.Parser.GTFSRealtime)

    enhanced_children =
      source_children(config, :gtfs_realtime_enhanced, Concentrate.Parser.GTFSRealtimeEnhanced)

    children = realtime_children ++ enhanced_children

    {child_ids(children), children}
  end

  defp source_children(config, key, parser) do
    for {source, url} <- Keyword.get(config, key, []) do
      {url, opts, parser} =
        case url do
          {url, opts} when is_binary(url) ->
            {url, opts,
             {parser,
              Keyword.take(
                opts,
                ~w(routes excluded_routes max_future_time headers fetch_after drop_fields)a
              )}}

          url when is_binary(url) ->
            {url, [], parser}
        end

      child_spec(
        {
          Concentrate.producer_for_url(url),
          {url, [name: source, parser: parser] ++ opts}
        },
        id: source
      )
    end
  end

  def merge(source_names, config) do
    [
      {
        Concentrate.MergeFilter,
        name: :merge_filter,
        subscribe_to: source_names,
        buffer_size: 1,
        filters: Keyword.get(config, :filters, []),
        group_filters: Keyword.get(config, :group_filters, [])
      }
    ]
  end

  def source_reporters(source_names, reporter_modules) when is_list(reporter_modules) do
    for module <- reporter_modules do
      child_spec(
        {Concentrate.SourceReporter.Consumer, module: module, subscribe_to: source_names},
        id: module
      )
    end
  end

  def reporters(reporter_modules) when is_list(reporter_modules) do
    for module <- reporter_modules do
      child_spec(
        {Concentrate.Reporter.Consumer,
         module: module, subscribe_to: [merge_filter: [max_demand: 10]]},
        id: module
      )
    end
  end

  def encoders(config) do
    children =
      for encoder_config <- config[:files] || [] do
        {filename, encoder, opts} =
          case encoder_config do
            {filename, encoder} -> {filename, encoder, []}
            _ -> encoder_config
          end

        opts =
          Keyword.replace_lazy(opts, :selector, fn selector ->
            case selector do
              {mod, fun, args} -> &apply(mod, fun, [&1 | args])
              fun when is_function(fun, 1) -> fun
            end
          end)

        child_spec(
          {
            Concentrate.Encoder.ProducerConsumer,
            name: encoder,
            files: [{filename, encoder}],
            dispatcher: GenStage.BroadcastDispatcher,
            subscribe_to: [
              {:merge_filter, opts}
            ]
          },
          id: encoder
        )
      end

    {child_ids(children), children}
  end

  def sink(config, output_names) do
    config =
      for {sink, sink_config} <- config do
        {sink, sink_config}
      end

    {Concentrate.Sink.Supervisor, config: config, sources: output_names}
  end

  defp child_ids(children) do
    for child <- children, do: child.id
  end
end
