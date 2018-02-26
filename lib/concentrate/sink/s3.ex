defmodule Concentrate.Sink.S3 do
  @moduledoc """
  Sink which writes files to an S3 bucket.
  """
  use GenStage
  alias ExAws.S3
  require Logger

  @config Application.get_env(:concentrate, :sink_s3) || []
  @ex_aws Keyword.get(@config, :ex_aws, ExAws)

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  @impl GenStage
  def init(opts) do
    bucket = Keyword.fetch!(opts, :bucket)
    prefix = Keyword.get(opts, :prefix, "")
    acl = Keyword.get(opts, :acl, :public_read)
    opts = Keyword.drop(opts, ~w(bucket prefix acl)a)
    {:consumer, %{bucket: bucket, prefix: prefix, acl: acl}, opts}
  end

  @impl GenStage
  def handle_events(events, _from, state) do
    for event <- events do
      upload_to_s3(event, state)
    end

    {:noreply, [], state}
  end

  @impl GenStage
  def handle_info({:ssl_closed, _}, state) do
    Logger.info(fn ->
      "#{__MODULE__} SSL closed error bucket=#{inspect(state.bucket)} prefix=#{
        inspect(state.prefix)
      }"
    end)

    {:noreply, [], state}
  end

  def handle_info(message, state) do
    Logger.warn(fn ->
      "#{__MODULE__} unexpected message bucket=#{inspect(state.bucket)} prefix=#{
        inspect(state.prefix)
      } message=#{inspect(message)}"
    end)

    {:noreply, [], state}
  end

  defp upload_to_s3({filename, body}, state) do
    full_filename = Path.join(state.prefix, filename)
    opts = [acl: state.acl, content_type: content_type(filename)]

    state.bucket
    |> S3.put_object(full_filename, body, opts)
    |> @ex_aws.request!

    Logger.info(fn ->
      "#{__MODULE__} updated: \
bucket=#{inspect(state.bucket)} \
path=#{inspect(full_filename)} \
bytes=#{byte_size(body)}"
    end)
  end

  defp content_type(filename) do
    do_content_type(Path.extname(filename))
  end

  defp do_content_type(".json"), do: "application/json"
  defp do_content_type(".pb"), do: "application/x-protobuf"
  defp do_content_type(_), do: "application/octet-stream"
end
