defmodule Concentrate.FeedUpdate do
  @moduledoc """
  Wraps up the list of updates provided by a given GTFS-RT feed.
  """
  import Concentrate.StructHelpers

  defstruct_accessors([
    :url,
    :timestamp,
    update_count: 0,
    updates: [],
    partial?: false
  ])

  def new(opts) do
    update_count = length(Keyword.get(opts, :updates, []))
    super([update_count: update_count] ++ opts)
  end

  @doc "Inverse of partial?"
  def full_update?(%__MODULE__{} = update) do
    not partial?(update)
  end

  defimpl Enumerable do
    def count(update) do
      {:ok, update.update_count}
    end

    def member?(_update, _element) do
      {:error, __MODULE__}
    end

    def reduce(update, acc, fun) do
      Enumerable.List.reduce(update.updates, acc, fun)
    end

    def slice(update) do
      {:ok, update.update_count, &Concentrate.FeedUpdate.updates/1}
    end
  end
end
