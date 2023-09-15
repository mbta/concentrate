defmodule Concentrate.TestMergeable do
  @moduledoc """
  Simple Mergeable for testing. Value is a list of items, and merging is a
  unique, sorted list of both provided values.
  """
  use ExUnitProperties
  defstruct [:key, :value]

  def new(key, value) do
    %__MODULE__{
      key: key,
      value: List.wrap(value)
    }
  end

  @doc """
  Helper which returns a StreamData of TestMergeables.
  """
  @spec mergeables :: StreamData.t()
  def mergeables do
    # get a keyword list of integers, filter out duplicate keys, then create
    # mergeables
    gen all(
          length <- integer(0..9),
          keys <- uniq_list_of(key(), length: length),
          values <- list_of(integer(), length: length)
        ) do
      keys
      |> Enum.zip(values)
      |> Enum.map(fn {k, v} -> new(k, v) end)
    end
  end

  defp key do
    StreamData.string(:alphanumeric, length: 1)
    |> StreamData.map(&String.to_atom/1)
  end

  defimpl Concentrate.Mergeable do
    def key(%{key: key}), do: key

    def related_keys(_), do: []

    def merge(first, second) do
      value =
        [first.value, second.value]
        |> Enum.concat()
        |> Enum.uniq()
        |> Enum.sort()

      @for.new(first.key, value)
    end
  end
end
