defmodule Concentrate.Sink.Filesystem do
  @moduledoc """
  Sink which writes files to the local filesytem.
  """
  require Logger

  def start_link(opts, file_data)

  def start_link(opts, {filename, body, file_opts}) do
    if file_opts[:partial?] do
      :ignore
    else
      start_link(opts, {filename, body})
    end
  end

  def start_link(opts, {filename, body}) do
    directory = Keyword.fetch!(opts, :directory)

    Task.start_link(fn ->
      path = Path.join(directory, filename)
      directory = Path.dirname(path)
      File.mkdir_p!(directory)
      File.write!(path, body)

      _ =
        Logger.info(fn ->
          "#{__MODULE__} updated: path=#{inspect(path)} bytes=#{byte_size(body)}"
        end)

      :ok
    end)
  end
end
