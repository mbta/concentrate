defmodule Concentrate.VehiclePositionTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.VehiclePosition
  alias Concentrate.Mergeable

  describe "Concentrate.Mergeable" do
    test "merge/2 takes the latest of the two" do
      first = new(last_updated: 1, latitude: 1, longitude: 1)
      second = new(last_updated: 2, latitude: 2, longitude: 2)
      assert Mergeable.merge(first, second) == second
      assert Mergeable.merge(second, first) == second
    end
  end
end
