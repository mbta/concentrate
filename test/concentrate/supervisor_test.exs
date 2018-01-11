defmodule Concentrate.SupervisorTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Supervisor

  describe "start_link/0" do
    test "can start the application" do
      assert {:ok, _pid} = start_link()
    end
  end

  describe "children/1" do
    test "builds the right number of children" do
      # currently, the right number is 3: alerts, GTFS, pipeline
      actual = children([])

      assert length(actual) == 3
    end
  end
end
