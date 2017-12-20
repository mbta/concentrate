defmodule Concentrate.MergeTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties
  import Concentrate.Merge
  alias Concentrate.{TestMergeable, VehiclePosition}

  describe "merge/1" do
    test "base cases" do
      item = TestMergeable.new(:key, 1)
      assert merge([]) == []
      assert merge([item]) == [item]
    end

    test "merges items which share a key together" do
      initial = [
        TestMergeable.new(:key, 1),
        TestMergeable.new(:key, 2)
      ]

      expected = [
        TestMergeable.new(:key, [1, 2])
      ]

      actual = merge(initial)
      assert actual == expected
    end

    test "items with different keys are kept separate" do
      initial = [
        TestMergeable.new(:first, 1),
        TestMergeable.new(:second, 2),
        TestMergeable.new(:first, 3)
      ]

      expected = [
        TestMergeable.new(:first, [1, 3]),
        TestMergeable.new(:second, [2])
      ]

      actual = merge(initial)
      assert actual == expected
    end

    test "can handle more than 2 items per key" do
      initial =
        for i <- 0..10 do
          TestMergeable.new(:key, i)
        end

      expected = [
        TestMergeable.new(:key, Enum.into(0..10, []))
      ]

      actual = merge(initial)
      assert actual == expected
    end

    test "can handle multiple types of Mergeable" do
      expected = [
        TestMergeable.new("vehicle", 0),
        VehiclePosition.new(id: "vehicle")
      ]

      actual = merge(expected)
      assert actual == expected
    end

    test "can handle other types of Enumerable" do
      expected = [TestMergeable.new(:key, 0)]

      actual =
        expected
        |> Stream.take(1)
        |> merge

      assert actual == expected
    end

    property "keys always appear in the original order" do
      check all mergeables <- TestMergeable.mergeables() do
        expected =
          mergeables
          |> Enum.map(& &1.key)
          |> Enum.uniq()

        actual =
          for item <- merge(mergeables) do
            item.key
          end

        assert actual == expected
      end
    end

    property "all values are present at the end" do
      check all mergeables <- TestMergeable.mergeables() do
        expected =
          mergeables
          |> Enum.flat_map(& &1.value)
          |> Enum.uniq()
          |> Enum.sort()

        # Merged values should already be unique
        actual =
          mergeables
          |> merge
          |> Enum.flat_map(& &1.value)
          |> Enum.sort()

        assert actual == expected
      end
    end
  end
end
