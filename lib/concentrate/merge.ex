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
    |> Enum.reduce(%{}, &merge_item/2)
    |> Map.values()
    |> Enum.sort()
    |> Enum.map(&elem(&1, 1))
  end

  defp merge_item(item, acc) do
    key = {Mergeable.impl_for!(item), Mergeable.key(item)}

    case Map.fetch(acc, key) do
      :error ->
        Map.put(acc, key, {map_size(acc), item})

      {:ok, {existing_index, existing}} ->
        %{acc | key => {existing_index, Mergeable.merge(existing, item)}}
    end
  end
end
