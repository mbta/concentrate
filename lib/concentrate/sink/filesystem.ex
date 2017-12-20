defmodule Concentrate.Sink.Filesystem do
  @moduledoc """
  Sink which writes files to the local filesytem.
  """
  use GenStage
  require Logger

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  @impl GenStage
  def init(opts) do
    directory = Keyword.fetch!(opts, :directory)
    opts = Keyword.drop(opts, [:directory])
    {:consumer, directory, opts}
  end

  @impl GenStage
  def handle_events(events, _from, state) do
    for {filename, body} <- events do
      path = Path.join(state, filename)
      File.write!(path, body)
      Logger.info(fn -> "#{__MODULE__}: #{path} updated: #{byte_size(body)} bytes" end)
    end

    {:noreply, [], state}
  end
end
