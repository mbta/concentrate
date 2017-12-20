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
    # generates a list of possible keys, then random mergeables with keys from that list
    ExUnitProperties.gen all keys <-
                               StreamData.list_of(StreamData.atom(:alphanumeric), min_length: 1),
                             mergeables <- mergeables_from_keys(keys) do
      mergeables
    end
  end

  defp mergeables_from_keys(keys) do
    ExUnitProperties.gen all key <- StreamData.member_of(keys),
                             mergeables <- StreamData.list_of(mergeable(key)) do
      mergeables
    end
  end

  defp mergeable(key) do
    ExUnitProperties.gen all value <- StreamData.integer() do
      new(key, value)
    end
  end

  defimpl Concentrate.Mergeable do
    def key(%{key: key}), do: key

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
