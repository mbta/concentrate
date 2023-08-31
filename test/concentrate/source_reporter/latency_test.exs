defmodule Concentrate.SourceReporter.LatencyTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.SourceReporter.Latency

  describe "log/2" do
    test "logs latency/frequency of a feed" do
      state = init()

      assert {[], state} = log(update("one"), state)
      Process.sleep(100)
      assert {[], state} = log(update("two"), state)
      Process.sleep(100)
      assert {[latency: latency, frequency: frequency], _state} = log(update("one"), state)
      # basically no processing time
      assert_in_delta latency, 0, 0.05
      # time since last feed
      assert_in_delta frequency, 0.2, 0.05
    end
  end

  defp update(url) do
    Concentrate.FeedUpdate.new(
      url: url,
      timestamp: System.system_time(:millisecond) / 1_000
    )
  end
end
