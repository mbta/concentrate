defmodule Concentrate.Merge.TableTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties
  import Concentrate.Merge.Table
  alias Concentrate.{Merge, TestMergeable}

  describe "items/2" do
    property "with one source, returns the latest data, merged" do
      check all all_mergeables <- list_of_mergeables() do
        expected = Merge.merge(List.last(all_mergeables))
        from = :from
        table = new()
        table = add(table, from)
        table = update(table, from, List.last(all_mergeables))
        assert items(table) == expected
      end
    end

    property "with multiple sources, returns the merged data" do
      check all multi_source_mergeables <- list_of_mergeables() do
        expected =
          multi_source_mergeables
          |> List.flatten()
          |> Merge.merge()

        table =
          Enum.reduce(multi_source_mergeables, new(), fn mergeables, table ->
            from = make_ref()
            table = add(table, from)
            update(table, from, mergeables)
          end)

        actual = items(table)

        assert Enum.sort(actual) == Enum.sort(expected)
      end
    end

    property "updating a source returns the latest data for that source" do
      check all all_mergeables <- list_of_mergeables() do
        from = :from
        table = new()
        table = add(table, from)
        expected = Merge.merge(List.last(all_mergeables))

        table =
          Enum.reduce(all_mergeables, table, fn mergeables, table ->
            update(table, from, mergeables)
          end)

        assert items(table) == expected
      end
    end
  end

  defp list_of_mergeables do
    list_of(TestMergeable.mergeables(), min_length: 1, max_length: 3)
  end
end
