defmodule Concentrate.Sink.S3 do
  @moduledoc """
  Sink which writes files to an S3 bucket.
  """
  alias ExAws.S3
  require Logger

  @ex_aws Application.compile_env(:concentrate, [:sink_s3, :ex_aws], ExAws)

  def start_link(opts, file_data)

  def start_link(opts, {filename, body, file_opts}) do
    if file_opts[:partial?] do
      :ignore
    else
      start_link(opts, {filename, body})
    end
  end

  def start_link(opts, {filename, body}) do
    opts = Concentrate.unwrap_values(opts)
    bucket = Keyword.fetch!(opts, :bucket)
    prefix = Keyword.get(opts, :prefix, "")
    acl = Keyword.get(opts, :acl, :public_read)
    state = %{bucket: bucket, prefix: prefix, acl: acl}
    Task.start_link(__MODULE__, :upload_to_s3, [{filename, body}, state])
  end

  def upload_to_s3({filename, body}, state) do
    full_filename = Path.join(state.prefix, filename)
    opts = [acl: state.acl, content_type: content_type(filename)]

    state.bucket
    |> S3.put_object(full_filename, body, opts)
    |> @ex_aws.request!

    _ =
      Logger.info(fn ->
        "#{__MODULE__} updated: \
bucket=#{inspect(state.bucket)} \
path=#{inspect(full_filename)} \
bytes=#{byte_size(body)}"
      end)

    :ok
  end

  defp content_type(filename) do
    do_content_type(Path.extname(filename))
  end

  defp do_content_type(".json"), do: "application/json"
  defp do_content_type(".pb"), do: "application/x-protobuf"
  defp do_content_type(_), do: "application/octet-stream"
end
