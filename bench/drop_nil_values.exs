defmodule DropNilValues do
  def reordered(map) do
    :maps.fold(
      fn
        _k, v, acc when not is_nil(v) -> acc
        k, nil, acc -> Map.delete(acc, k)
      end,
      map,
      map
    )
  end

  def delete(map) do
    :maps.fold(
      fn
        k, nil, acc -> Map.delete(acc, k)
        _k, _v, acc -> acc
      end,
      map,
      map
    )
  end

  def original(map) do
    :maps.fold(
      fn
        _k, nil, acc -> acc
        k, v, acc -> Map.put(acc, k, v)
      end,
      %{},
      map
    )
  end
end

Benchee.run(
  %{
    reordered: &DropNilValues.reordered/1,
    delete: &DropNilValues.delete/1,
    original: &DropNilValues.original/1
  },
  print: [fast_warning: false],
  inputs: %{
    third_nils_big: Map.new(0..10, fn i ->
      if div(i, 3) == 0, do: {i, i}, else: {i, nil}
    end),
    quarter_nils_big: Map.new(0..10, fn i ->
      if div(i, 4) == 0, do: {i, i}, else: {i, nil}
    end),
    half_nils_big: Map.new(0..10, fn i ->
      if div(i, 2) == 0, do: {i, i}, else: {i, nil}
    end)
  }
)
