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
    # NB: relies on Map.values/1 returning items in the original order
    items
    |> Enum.reduce(%{}, &merge_item/2)
    |> Map.values()
  end

  defp merge_item(item, acc) do
    key = Mergeable.key(item)

    value =
      case Map.fetch(acc, key) do
        :error ->
          item

        {:ok, existing} ->
          Mergeable.merge(existing, item)
      end

    Map.put(acc, key, value)
  end
end
