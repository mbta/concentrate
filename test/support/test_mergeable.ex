defmodule Concentrate.TestMergeable do
  @moduledoc """
  Simple Mergeable for testing. Value is a list of items, and merging is a
  unique, sorted list of both provided values.
  """
  defstruct [:key, :value]

  def new(key, value) do
    %__MODULE__{
      key: key,
      value: List.wrap(value)
    }
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
