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
    module = Mergeable.impl_for!(item)
    key = {module, module.key(item)}

    case acc do
      %{^key => {existing_index, existing}} ->
        %{acc | key => {existing_index, module.merge(existing, item)}}

      acc ->
        Map.put(acc, key, {map_size(acc), item})
    end
  end
end
