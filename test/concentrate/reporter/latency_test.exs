defmodule Concentrate.Reporter.LatencyTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Reporter.Latency

  describe "log/2" do
    test "logs number of milliseconds between calls" do
      state = init()
      assert {[update_latency_ms: time], state} = log([{nil, [], []}], state)
      assert_in_delta time, 0, 50
      :timer.sleep(100)
      assert {[update_latency_ms: time], _} = log([{nil, [], []}], state)
      assert_in_delta time, 100, 50
    end
  end
end
