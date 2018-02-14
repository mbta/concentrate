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
      directory = Path.dirname(path)
      File.mkdir_p!(directory)
      File.write!(path, body)

      Logger.info(fn ->
        "#{__MODULE__} updated: path=#{inspect(path)} bytes=#{byte_size(body)}"
      end)
    end

    {:noreply, [], state}
  end
end
