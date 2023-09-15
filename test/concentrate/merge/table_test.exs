defmodule Concentrate.Merge.TableTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties
  import Concentrate.Merge.Table
  alias Concentrate.{Merge, TestMergeable}

  describe "items/2" do
    property "with one source, returns the data" do
      check all(mergeables <- TestMergeable.mergeables()) do
        from = :from
        table = new()
        table = update(table, from, mergeables)
        assert Enum.sort(items(table)) == Enum.sort(Merge.merge(mergeables))
      end
    end

    property "partial updates keep the last seen value for the given Mergeable" do
      check all(first <- TestMergeable.mergeables(), second <- TestMergeable.mergeables()) do
        from = :from

        actual =
          new()
          |> partial_update(from, first)
          |> then(fn {table, _} -> partial_update(table, from, second) end)
          |> then(fn {table, _} -> items(table) end)
          |> Enum.sort()

        expected =
          Map.merge(
            Map.new(first, &{&1.key, &1}),
            Map.new(second, &{&1.key, &1})
          )
          |> Map.values()
          |> Enum.sort()

        assert expected == actual
      end
    end

    property "partial updates return a list of updated keys" do
      check all(
              first <- TestMergeable.mergeables(),
              second <- TestMergeable.mergeables()
            ) do
        from = :from

        {table, second_keys} =
          new()
          |> partial_update(from, first)
          |> then(fn {table, _} -> partial_update(table, from, second) end)

        actual = items(table, second_keys)

        expected =
          Map.merge(
            Map.new(first, &{&1.key, &1}),
            Map.new(second, &{&1.key, &1})
          )
          # only keep the keys from the second item
          |> Map.take(Enum.map(second, & &1.key))
          |> Map.values()
          |> Enum.sort()

        assert expected == actual
      end
    end

    property "updated keys can be used to retrieve only those merges" do
      check all(
              first <- TestMergeable.mergeables(),
              second <- TestMergeable.mergeables()
            ) do
        {table, second_table_keys} =
          new()
          |> update(:first, first)
          |> partial_update(:second, second)

        actual = items(table, second_table_keys)

        second_keys = Enum.map(second, & &1.key)

        expected =
          (first ++ second)
          |> Enum.filter(&(&1.key in second_keys))
          |> Merge.merge()

        assert expected == actual
      end
    end

    property "with multiple sources, returns the merged data" do
      check all(multi_source_mergeables <- sourced_mergeables()) do
        # reverse so we get the latest data
        # get the uniq sources
        expected =
          multi_source_mergeables
          |> Enum.reverse()
          |> Enum.uniq_by(&elem(&1, 0))
          |> Enum.flat_map(&elem(&1, 1))
          |> Merge.merge()

        table =
          Enum.reduce(multi_source_mergeables, new(), fn {source, mergeables}, table ->
            table
            |> update(source, mergeables)
          end)

        actual = items(table)

        assert Enum.sort(actual) == Enum.sort(expected)
      end
    end

    property "updating a source returns the latest data for that source" do
      check all(all_mergeables <- list_of_mergeables()) do
        from = :from
        table = new()
        expected = List.last(all_mergeables)

        table =
          Enum.reduce(all_mergeables, table, fn mergeables, table ->
            update(table, from, mergeables)
          end)

        assert Enum.sort(items(table)) == Enum.sort(expected)
      end
    end
  end

  defp sourced_mergeables do
    list_of(
      {StreamData.atom(:alphanumeric), TestMergeable.mergeables()},
      min_length: 1,
      max_length: 3
    )
  end

  defp list_of_mergeables do
    list_of(TestMergeable.mergeables(), min_length: 1, max_length: 3)
  end
end
