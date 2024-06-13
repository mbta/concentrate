defmodule Concentrate.Producer.S3 do
  @moduledoc """
  GenStage Producer for s3.
  """

  use GenStage
  require Logger

  @start_link_opts [:name]

  defmodule State do
    @moduledoc false
    defstruct [
      :bucket,
      :etag,
      :ex_aws,
      :fetch_after,
      :last_fetch,
      :last_modified,
      :next_fetch_ref,
      :object,
      :parser_opts,
      :parser,
      :url
    ]
  end

  alias __MODULE__.State

  def start_link({url, opts}) when is_binary(url) and is_list(opts) do
    start_link_opts = Keyword.take(opts, @start_link_opts)
    opts = Keyword.drop(opts, @start_link_opts)
    GenStage.start_link(__MODULE__, {url, opts}, start_link_opts)
  end

  @impl GenStage
  def init({url, opts}) do
    {parser, parser_opts} =
      case Keyword.fetch!(opts, :parser) do
        module when is_atom(module) ->
          {&module.parse/2, []}

        {module, opts} when is_atom(module) and is_list(opts) ->
          {&module.parse/2, opts}

        fun when is_function(fun, 2) ->
          {fun, []}
      end

    {bucket, object} = parse_s3_url(url)

    fetch_after = Keyword.get(opts, :fetch_after)
    ex_aws = Keyword.get(opts, :ex_aws, ExAws)

    {
      :producer,
      %State{
        bucket: bucket,
        ex_aws: ex_aws,
        fetch_after: fetch_after,
        last_fetch: monotonic_now() - fetch_after - 1,
        object: object,
        parser_opts: parser_opts,
        parser: parser,
        url: url
      },
      dispatcher: GenStage.BroadcastDispatcher
    }
  end

  defp parse_s3_url(url) do
    %URI{host: bucket, path: object} = URI.parse(url)

    {bucket, object}
  end

  @impl GenStage
  def handle_demand(_, state) do
    state = schedule_fetch(state)

    {:noreply, [], state}
  end

  @impl GenStage
  def handle_info(:fetch, state) do
    state = %{state | next_fetch_ref: nil, last_fetch: monotonic_now()}
    state = schedule_fetch(state)

    case state.ex_aws.request(
           ExAws.S3.get_object(state.bucket, state.object,
             if_none_match: state.etag,
             if_modified_since: state.last_modified
           )
         ) do
      {:ok, %{status_code: 200, body: body, headers: headers}} ->
        state = %{
          state
          | last_modified: get_header(headers, "last-modified"),
            etag: get_header(headers, "etag")
        }

        {:noreply, parse_response(body, state), state}

      {:ok, %{status_code: 304}} ->
        {:noreply, [], state}

      {_, error} ->
        Logger.warning(
          "#{__MODULE__} error fetching s3 url=#{state.url}} error=#{inspect(error, limit: :infinity)}"
        )

        {:noreply, [], state}
    end
  end

  defp schedule_fetch(%{next_fetch_ref: nil} = state) do
    next_fetch_after = max(state.last_fetch + state.fetch_after - monotonic_now(), 0)
    next_fetch_ref = Process.send_after(self(), :fetch, next_fetch_after)

    %{state | next_fetch_ref: next_fetch_ref}
  end

  # coveralls-ignore-start
  defp schedule_fetch(%{next_fetch_ref: _} = state) do
    # already scheduled!  this isn't always hit during testing (but it is
    # sometimes) so we skip the coverage check.
    state
  end

  # coveralls-ignore-stop

  defp monotonic_now do
    System.monotonic_time(:millisecond)
  end

  defp get_header(headers, header) do
    Enum.find_value(headers, fn {key, value} ->
      String.downcase(key) == header and value
    end)
  end

  defp parse_response(body, state) do
    case state.parser.(body, state.parser_opts) do
      [] -> [:empty]
      events -> events
    end
  end
end
