defmodule Concentrate.FilterTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties
  import Concentrate.Filter

  defmodule OnlyEvenFilter do
    @moduledoc false
    @behaviour Concentrate.Filter

    def init do
      {:parallel, :state}
    end

    def filter(value, :state) do
      if Integer.mod(value, 2) == 0 do
        {:cont, value, :ignored}
      else
        {:skip, :also_ignored}
      end
    end

    @doc "test helper to process the data as expected"
    def expected(data) do
      Enum.filter(data, &(Integer.mod(&1, 2) == 0))
    end
  end

  defmodule AddPreviousFilter do
    @moduledoc false
    @behaviour Concentrate.Filter

    def init do
      {:serial, 0}
    end

    def filter(value, previous) do
      # adds the previous value to this value
      {:cont, value + previous, value}
    end

    @doc "test helper to process the data as expected"
    def expected(data) do
      [data, [0 | data]]
      |> Enum.zip()
      |> Enum.map(fn {x, y} -> x + y end)
    end
  end

  alias __MODULE__.{OnlyEvenFilter, AddPreviousFilter}

  describe "run/2" do
    property "parallel filter removes even numbers" do
      check all data <- list_of(integer()) do
        expected = OnlyEvenFilter.expected(data)
        actual = run(data, [OnlyEvenFilter])
        assert actual == expected
      end
    end

    property "serial filter adds the previous value" do
      check all data <- list_of(integer()) do
        expected = AddPreviousFilter.expected(data)
        actual = run(data, [AddPreviousFilter])
        assert actual == expected
      end
    end

    property "filters are applied first to last" do
      check all data <- list_of(integer()) do
        assert run(data, [OnlyEvenFilter, AddPreviousFilter]) ==
                 data |> OnlyEvenFilter.expected() |> AddPreviousFilter.expected()

        assert run(data, [AddPreviousFilter, OnlyEvenFilter]) ==
                 data |> AddPreviousFilter.expected() |> OnlyEvenFilter.expected()
      end
    end
  end
end
