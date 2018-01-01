defmodule Concentrate.DebounceTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Debounce

  describe "handle_events/4" do
    test "keeps track of the last event" do
      {_, state, _} = init(timeout: 100)

      {:noreply, [], state} = handle_events([1, 2, 3], :from, state)
      assert state.timer
      refute_received :timeout
      {:noreply, [], state} = handle_events([4, 5, 6], :from, state)
      assert state.events == [6]
      assert_receive :timeout, 500
    end
  end

  describe "handle_info(:timeout)" do
    test "sends as an event the last event received" do
      {_, state, _} = init(timeout: 100)
      {:noreply, [], state} = handle_events([1, 2, 3], :from, state)
      {:noreply, [], state} = handle_events([4, 5, 6], :from, state)
      assert {:noreply, [6], state, :hibernate} = handle_info(:timeout, state)
      assert state.events == []
      refute state.timer
    end
  end
end
