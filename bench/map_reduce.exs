defmodule MapReduce do
  def original(map) do
    acc = {:cont, 0}
    Enumerable.List.reduce(:maps.to_list(map), acc, &sum/2)
  end

  def maybe_iterator(map) when map_size(map) <= 131_072 do # 2 ** 9
    original(map)
  end
  def maybe_iterator(map) do
    iterator(map)
  end

  def iterator(map) do
    acc = {:cont, 0}
    iter = :maps.iterator(map)
    reduce_iter(iter, acc, &sum/2)
  end

  defp reduce_iter(_iter, {:halt, acc}, _fun), do: {:halted, acc}
  defp reduce_iter(iter, {:suspend, acc}, fun), do: {:suspended, acc, &reduce_iter(iter, &1, fun)}
  defp reduce_iter(iter, {:cont, acc}, fun) do
    case :maps.next(iter) do
      {key, value, iter} ->
        reduce_iter(iter, fun.({key, value}, acc), fun)
      :none ->
        {:done, acc}
    end
  end

  defp sum(_, b), do: {:cont, b}
end

Benchee.run(
  %{
    original: &MapReduce.original/1,
    maybe_iterator: &MapReduce.iterator/1,
    iterator: &MapReduce.iterator/1,
  },
  warmup: 1,
  memory_time: 2,
  print: [fast_warning: false],
  inputs: %{
    small: Map.new(0..31, fn i -> {i, i} end),
    medium: Map.new(0..1023, fn i -> {i, i} end),
    large: Map.new(0..32_767, fn i -> {i, i} end),
    one_thirty_two: Map.new(0..(div(1_048_576, 8) - 1), fn i -> {i, i} end),
    xlarge: Map.new(0..1_048_575, fn i -> {i, i} end)
  }
)
