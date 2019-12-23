defmodule Concentrate.FilterTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties
  import Concentrate.Filter

  defmodule OnlyEvenFilter do
    @moduledoc false
    @behaviour Concentrate.Filter

    def filter(value) do
      if Integer.mod(value, 2) == 0 do
        {:cont, value}
      else
        :skip
      end
    end

    @doc "test helper to process the data as expected"
    def expected(data) do
      Enum.filter(data, &(Integer.mod(&1, 2) == 0))
    end
  end

  defmodule AddOneFilter do
    @moduledoc false
    @behaviour Concentrate.Filter

    def filter(value) do
      {:cont, value + 1}
    end

    @doc "test helper to process the data as expected"
    def expected(data) do
      for d <- data do
        d + 1
      end
    end
  end

  alias __MODULE__.{OnlyEvenFilter, AddOneFilter}

  describe "run/2" do
    property "parallel filter removes even numbers" do
      check all(data <- list_of(integer())) do
        expected = OnlyEvenFilter.expected(data)
        actual = run(data, [OnlyEvenFilter])
        assert actual == expected
      end
    end

    property "serial filter adds the previous value" do
      check all(data <- list_of(integer())) do
        expected = AddOneFilter.expected(data)
        actual = run(data, [AddOneFilter])
        assert actual == expected
      end
    end

    property "filters are applied first to last" do
      check all(data <- list_of(integer())) do
        assert run(data, [OnlyEvenFilter, AddOneFilter]) ==
                 data |> OnlyEvenFilter.expected() |> AddOneFilter.expected()

        assert run(data, [AddOneFilter, OnlyEvenFilter]) ==
                 data |> AddOneFilter.expected() |> OnlyEvenFilter.expected()
      end
    end
  end
end
