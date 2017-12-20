defmodule Concentrate.Merge do
  @moduledoc """
  Merges a list of Concentrate.Mergeable items.
  """
  alias Concentrate.Mergeable

  @doc """
  Implementation of the merge algorithm.

  We walk through the list of items, grouping them by key and merging as we
  come across items with a shared key. Order is preserved.
  """
  @spec merge(Enumerable.t()) :: [Mergeable.t()]
  def merge(items)

  def merge([]) do
    []
  end

  def merge([_item] = items) do
    items
  end

  def merge(items) do
    items
    |> Stream.with_index()
    |> Enum.reduce(%{}, &merge_item/2)
    |> Enum.sort_by(fn {_key, {_item, index}} -> index end)
    |> Enum.map(fn {_key, {item, _index}} -> item end)
  end

  defp merge_item({item, index}, acc) do
    key = {Mergeable.impl_for!(item), Mergeable.key(item)}

    value =
      case Map.fetch(acc, key) do
        :error ->
          {item, index}

        {:ok, {existing, existing_index}} ->
          {Mergeable.merge(existing, item), existing_index}
      end

    Map.put(acc, key, value)
  end
end
