defmodule Concentrate.VehiclePositionTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.VehiclePosition
  alias Concentrate.Mergeable

  describe "Concentrate.Mergeable" do
    test "merge/2 takes the latest of the two" do
      first = new(last_updated: DateTime.from_unix!(1))
      second = new(last_updated: DateTime.from_unix!(2))
      assert Mergeable.merge(first, second) == first
      assert Mergeable.merge(second, first) == first
    end
  end
end
