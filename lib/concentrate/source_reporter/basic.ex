defmodule Concentrate.SourceReporter.Basic do
  @moduledoc """
  Logs basic (count. partial update or not) per-feed.
  """
  @behaviour Concentrate.SourceReporter
  alias Concentrate.FeedUpdate

  @impl Concentrate.SourceReporter
  def init do
    %{}
  end

  @impl Concentrate.SourceReporter
  def log(update, state) do
    count = Enum.count(update)
    partial? = FeedUpdate.partial?(update)
    timestamp = FeedUpdate.timestamp(update)

    stats = [
      count: count,
      partial?: partial?,
      timestamp: timestamp
    ]

    {stats, state}
  end
end
