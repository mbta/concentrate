defmodule Concentrate.MergeFilterTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties
  import Concentrate.MergeFilter
  alias Concentrate.{Merge, TestMergeable, TripUpdate, VehiclePosition, StopTimeUpdate}

  describe "handle_subscribe/4" do
    test "asks the producer for demand" do
      from = make_from()
      {_, state, _} = init([])
      {_, _state} = handle_subscribe(:producer, [], from, state)
      assert_received {:"$gen_producer", ^from, {:ask, 1}}
    end
  end

  describe "handle_cancel/3" do
    test "cleans up state if a producer dies" do
      from = make_from()
      {_, original_state, _} = init([])
      {_, state} = handle_subscribe(:producer, [], from, original_state)
      assert {:noreply, [], new_state} = handle_cancel({:cancel, :whatever}, from, state)
      assert original_state == new_state
    end
  end

  describe "handle_events/2" do
    test "schedules a timeout" do
      from = make_from()
      {_, state, _} = init(timeout: 100)
      {_, state} = handle_subscribe(:producer, [], from, state)
      {:noreply, [], state} = handle_events([[], [], []], from, state)
      assert state.timer
      refute_received :timeout
      {:noreply, [], _state} = handle_events([[], [], []], from, state)
      assert_receive :timeout, 500
    end

    test "runs the events through the filter" do
      data = [
        VehiclePosition.new(latitude: 1, longitude: 1),
        expected = VehiclePosition.new(trip_id: "trip", latitude: 2, longitude: 2)
      ]

      events = [data]
      filters = [Concentrate.Filter.VehicleWithNoTrip]
      from = make_from()
      {_, state, _} = init(filters: filters)
      {_, state} = handle_subscribe(:producer, [], from, state)
      {:noreply, [], state} = handle_events(events, from, state)
      assert {:noreply, [[^expected]], _state} = handle_info(:timeout, state)
    end

    test "ensures items are in the order TripUpdate, VehiclePosition, StopTimeUpdate" do
      data = [
        three = StopTimeUpdate.new(stop_sequence: 1),
        four = StopTimeUpdate.new(stop_sequence: 2),
        two = VehiclePosition.new(latitude: 1, longitude: 1),
        one = TripUpdate.new([])
      ]

      expected = [one, two, three, four]

      events = [data]
      from = make_from()
      {_, state, _} = init([])
      {_, state} = handle_subscribe(:producer, [], from, state)
      {:noreply, [], state} = handle_events(events, from, state)
      assert {:noreply, [^expected], _state} = handle_info(:timeout, state)
    end

    property "with multiple sources, returns the merged data" do
      check all multi_source_mergeables <- list_of_mergeables() do
        {_, state, _} = init([])

        expected =
          multi_source_mergeables
          |> List.flatten()
          |> Merge.merge()

        acc = {:noreply, [], state}

        {:noreply, [], state} =
          Enum.reduce(multi_source_mergeables, acc, fn mergeables, {_, _, state} ->
            from = make_from()
            {_, state} = handle_subscribe(:producer, [], from, state)
            handle_events([mergeables], from, state)
          end)

        {:noreply, [actual], _state} = handle_info(:timeout, state)

        assert Enum.sort(actual) == Enum.sort(expected)
      end
    end

    test "asks sources from which we've received data for more" do
      producer_0 = make_from()
      producer_1 = make_from()
      {_, state, _} = init([])
      {_, state} = handle_subscribe(:producer, [], producer_0, state)
      {_, state} = handle_subscribe(:producer, [], producer_1, state)
      clear_mailbox()
      {:noreply, _, state} = handle_events([[]], producer_0, state)
      {:noreply, _, _state} = handle_info(:timeout, state)
      assert_received {:"$gen_producer", ^producer_0, {:ask, 1}}
      refute_received {:"$gen_producer", ^producer_1, _}
    end
  end

  defp make_from do
    {self(), make_ref()}
  end

  defp list_of_mergeables do
    list_of(TestMergeable.mergeables(), min_length: 1, max_length: 3)
  end

  defp clear_mailbox do
    receive do
      _ -> clear_mailbox()
    after
      0 -> :ok
    end
  end
end
