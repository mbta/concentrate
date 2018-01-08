defmodule Concentrate.Merge.Table do
  @moduledoc """
  Maintains a table of merged values from different sources.
  """
  defstruct data: %{}
  alias Concentrate.Merge

  def new do
    %__MODULE__{}
  end

  def add(table, source_name) do
    put_in(table.data[source_name], [])
  end

  def remove(table, source_name) do
    %{table | data: Map.delete(table.data, source_name)}
  end

  def update(table, source_name, items) do
    %{table | data: %{table.data | source_name => items}}
  end

  def items(table) do
    table.data
    |> Stream.flat_map(&elem(&1, 1))
    |> Merge.merge()
  end
end
