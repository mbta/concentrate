defmodule ConcentrateTest do
  use ExUnit.Case
  doctest Concentrate

  test "greets the world" do
    assert Concentrate.hello() == :world
  end
end
