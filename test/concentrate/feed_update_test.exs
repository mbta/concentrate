defmodule Concentrate.FeedUpdateTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Concentrate.FeedUpdate

  describe "Enumerable" do
    property "implements count" do
      check all(u <- feed_update()) do
        assert length(FeedUpdate.updates(u)) == Enum.count(u)
      end
    end

    property "implements member?" do
      check all(u <- feed_update(), n <- update()) do
        assert n in u == n in FeedUpdate.updates(u)
      end
    end

    property "implements slice" do
      check all(u <- feed_update(), start <- integer(-5..5), stop <- integer(-5..5)) do
        assert Enum.slice(u, start..stop) == Enum.slice(FeedUpdate.updates(u), start..stop)
      end
    end

    property "implements reduce" do
      check all(u <- feed_update()) do
        assert Enum.sum(FeedUpdate.updates(u)) == Enum.reduce(u, 0, &(&1 + &2))
      end
    end
  end

  defp feed_update do
    gen all(updates <- list_of(update())) do
      FeedUpdate.new(updates: updates)
    end
  end

  defp update do
    integer(0..9)
  end
end
