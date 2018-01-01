defmodule Concentrate.Sink.GTFSRealtimeViz do
  @moduledoc """
  Sink which uses the gtfs_realtime_viz module to generate a comparison with an existing file.
  """
  use GenStage
  require Logger

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  @impl GenStage
  def init(opts) do
    directory = Keyword.fetch!(opts, :directory)
    urls = Keyword.fetch!(opts, :urls)
    config = Keyword.get(opts, :config, %{})
    path = Path.join(directory, "gtfs_realtime_diff.html")
    opts = Keyword.drop(opts, ~w(directory urls config)a)

    state = %{
      path: path,
      urls: urls,
      config: config
    }

    {:consumer, state, opts}
  end

  @impl GenStage
  def handle_events(events, _from, state) do
    update_new(events)
    update_remote(state.urls)

    if Enum.any?(events, &(elem(&1, 0) == "TripUpdates.pb")) do
      render_diff(state)
    end

    {:noreply, [], state}
  end

  defp update_new(events) do
    for {filename, body} <- events, Path.extname(filename) == ".pb" do
      GTFSRealtimeViz.new_message(:new, body, "generated")
    end
  end

  defp update_remote(urls) do
    urls
    |> Task.async_stream(&HTTPoison.get/1, ordered: false)
    |> Enum.each(fn {:ok, {:ok, %{body: remote_body}}} ->
      GTFSRealtimeViz.new_message(:remote, remote_body, "remote")
    end)
  end

  defp render_diff(state) do
    html = GTFSRealtimeViz.visualize_diff(:new, :remote, state.config)
    File.write!(state.path, html)

    Logger.info(fn ->
      "#{__MODULE__}: #{state.path} updated: #{byte_size(html)} bytes"
    end)
  end
end
