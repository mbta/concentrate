defmodule Concentrate.SourceReporter.Latency do
  @moduledoc """
  Logs per-feed latency/frequency.
  """
  @behaviour Concentrate.SourceReporter
  alias Concentrate.FeedUpdate

  @impl Concentrate.SourceReporter
  def init do
    %{}
  end

  @impl Concentrate.SourceReporter
  def log(update, last_updated) do
    now = System.system_time(:millisecond) / 1_000
    url = FeedUpdate.url(update)
    timestamp = FeedUpdate.timestamp(update) || now

    stats =
      case last_updated do
        %{^url => last_timestamp} ->
          [latency: now - timestamp, frequency: timestamp - last_timestamp]

        _ ->
          []
      end

    last_updated =
      if is_binary(url) do
        Map.put(last_updated, url, timestamp)
      else
        last_updated
      end

    {stats, last_updated}
  end
end
