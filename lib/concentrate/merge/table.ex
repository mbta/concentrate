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

  def add(%{data: data} = table, source_name) do
    %{table | data: Map.put_new(data, source_name, [])}
  end

  def remove(table, source_name) do
    %{table | data: Map.delete(table.data, source_name)}
  end

  def update(%{data: data} = table, source_name, items) do
    item_list = item_list(items, [])
    %{table | data: %{data | source_name => item_list}}
  end

  def items(%{data: empty}) when empty == %{} do
    []
  end

  def items(%{data: data}) do
    data
    |> fold_map
    |> Map.values()
    |> :lists.sort()
    |> reverse_second_element([])
  end

  defp item_list([], acc) do
    acc
  end

  defp item_list([item | rest], acc) do
    # since it's going into a map anyways, we can save ourselves a reverse
    module = Mergeable.impl_for!(item)
    acc = [{{module, module.key(item)}, item} | acc]
    item_list(rest, acc)
  end

  defp fold_map(map) do
    :maps.fold(fn _key, items, acc -> merge_list(items, acc) end, %{}, map)
  end

  defp merge_list(items, acc) when acc == %{} do
    # if there's no acc, we can build it directly with the indicies
    items
    |> build_indexed_list(0, [])
    |> Map.new()
  end

  defp merge_list(items, acc) do
    Enum.reduce(items, acc, fn {key, item}, acc ->
      case acc do
        %{^key => {index, existing}} ->
          {module, _} = key
          %{acc | key => {index, module.merge(existing, item)}}

        acc ->
          Map.put(acc, key, {map_size(acc), item})
      end
    end)
  end

  # Like Enum.with_index/1 but doesn't reverse the list at the end
  defp build_indexed_list([], _count, acc) do
    acc
  end

  defp build_indexed_list([{key, item} | rest], count, acc) do
    acc = [{key, {count, item}} | acc]
    build_indexed_list(rest, count + 1, acc)
  end

  # like Enum.map(list, &elem(&1, 1)) but doesn't reverse the list at the end
  defp reverse_second_element([], acc) do
    # since the items are in reverse order, we don't need to re-reverse afterwards
    acc
  end

  defp reverse_second_element([{_, value} | rest], acc) do
    reverse_second_element(rest, [value | acc])
  end
end
