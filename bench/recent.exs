defmodule BenchRecent do
  @moduledoc false
  @data Enum.to_list(0..1000)
  @values (for key <- ~w(a b c b c a)a do
    {key, @data}
  end)

  @selector {:_, :"$1"}

  def map_flat(_) do
    state = %{}
  {[_ | _], _} = Enum.reduce(@values, {nil, state}, fn {key, value}, {_, acc} ->
      acc = Map.put(acc, key, value)
      {Enum.flat_map(acc, &elem(&1, 1)), acc}
    end)
  end

  def ets(state) do
    [_ | _] = Enum.reduce(@values, nil, fn {key, value}, _ ->
      :ets.delete(state, key)
      inserts = for v <- value, do: {key, v}
      _ = :ets.insert(state, inserts)
      :ets.match(state, @selector)
    end)
  end
end

Benchee.run(%{
      "map_flat": &BenchRecent.map_flat/1,
      "ets": &BenchRecent.ets/1,
            },
  before_each: fn input -> :ets.new(:tab, [:bag]) end
)
