defmodule Concentrate.Merge.Table do
  @moduledoc """
  Maintains a table of merged values from different sources.

  We can be slightly clever to save ourselves some work.

  * When updating data, we can map over the items (to get the Mergeable implementation) without reversing at the end
  * Then, when building indexes, we know that the items are in reversed order and so we don't need to reverse again
  """
  defstruct data: %{}
  alias Concentrate.Mergeable

  def new do
    %__MODULE__{}
  end

  def remove(table, source_name) do
    %{table | data: Map.delete(table.data, source_name)}
  end

  def partial_update(%{data: data} = table, source_name, items) do
    new_item_list =
      Map.new(items, fn item ->
        module = Mergeable.impl_for!(item)
        key = {module, module.key(item)}
        {key, item}
      end)

    data = Map.update(data, source_name, new_item_list, &Map.merge(&1, new_item_list))
    {%{table | data: data}, Map.keys(new_item_list)}
  end

  def update(table, source_name, items) do
    {table, _} =
      table
      |> remove(source_name)
      |> partial_update(source_name, items)

    table
  end

  def items(table, keys \\ nil)

  def items(%{data: empty}, _keys) when empty == %{} do
    []
  end

  def items(%{data: data}, keys) do
    data
    |> fold_map(keys)
    |> include_related_values(keys, data)
    |> Map.values()
  end

  defp fold_map(map, keys)

  defp fold_map(_map, []) do
    %{}
  end

  defp fold_map(map, keys) do
    :maps.fold(fn _key, items, acc -> merge_list(items, keys, acc) end, %{}, map)
  end

  defp merge_list(items, nil, acc) when acc == %{} do
    # if there's no acc, we don't need to merge at all
    items
  end

  defp merge_list(items, keys, acc) when acc == %{} do
    Map.take(items, keys)
  end

  defp merge_list(items, nil, acc) do
    Map.merge(items, acc, fn {module, _}, item, existing ->
      module.merge(existing, item)
    end)
  end

  defp merge_list(items, keys, acc) do
    items
    |> Map.take(keys)
    |> merge_list(nil, acc)
  end

  defp include_related_values(items, keys, data)

  defp include_related_values(items, nil, _data) do
    items
  end

  defp include_related_values(items, _keys, data) do
    related_keys =
      items
      |> Enum.flat_map(fn {{mod, _key}, item} ->
        mod.related_keys(item)
      end)
      |> Enum.map(fn {mod, key} ->
        {Mergeable.impl_for!(struct!(mod)), key}
      end)

    related_items = fold_map(data, related_keys)

    Map.merge(items, related_items)
  end
end
