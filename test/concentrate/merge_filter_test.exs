defmodule Concentrate.MergeFilterTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties
  import ExUnit.CaptureLog, only: [capture_log: 1]
  import Concentrate.MergeFilter
  alias Concentrate.{Merge, TripDescriptor, VehiclePosition, StopTimeUpdate}
  alias Concentrate.Encoder.GTFSRealtimeHelpers

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
      {_, state, _} = init(initial_timeout: 100, timeout: 100)
      assert state.timer
      assert_receive :timeout, 500
      {:noreply, _, state} = handle_info(:timeout, state)

      {_, state} = handle_subscribe(:producer, [], from, state)
      {:noreply, [], state} = handle_events([[], [], []], from, state)
      assert state.timer
      refute_received :timeout
      {:noreply, [], _state} = handle_events([[], [], []], from, state)
      assert_receive :timeout, 500
    end

    test "runs the events through the filter" do
      data = [
        VehiclePosition.new(id: "one", latitude: 1, longitude: 1),
        expected = VehiclePosition.new(id: "two", trip_id: "trip", latitude: 2, longitude: 2)
      ]

      events = [data]
      filters = [Concentrate.Filter.VehicleWithNoTrip]
      from = make_from()
      {_, state, _} = init(filters: filters)
      {_, state} = handle_subscribe(:producer, [], from, state)
      {:noreply, [], state} = handle_events(events, from, state)
      assert {:noreply, [[{nil, [^expected], []}]], _state} = handle_info(:timeout, state)
    end

    test "runs the events through the filter with options" do
      data = [
        VehiclePosition.new(id: "one", latitude: 1, longitude: 1),
        expected = VehiclePosition.new(id: "two", trip_id: "trip", latitude: 2, longitude: 2)
      ]

      events = [data]
      filters = [{Concentrate.Filter.VehicleWithNoTrip, options: []}]
      from = make_from()
      {_, state, _} = init(filters: filters)
      {_, state} = handle_subscribe(:producer, [], from, state)
      {:noreply, [], state} = handle_events(events, from, state)
      assert {:noreply, [[{nil, [^expected], []}]], _state} = handle_info(:timeout, state)
    end

    test "can filter the grouped data" do
      defmodule Filter do
        @moduledoc false
        @behaviour Concentrate.GroupFilter
        def filter({trip, _vehicles, stop_updates}) do
          {trip, [], stop_updates}
        end
      end

      from = make_from()
      {_, state, _} = init(group_filters: [__MODULE__.Filter])
      {_, state} = handle_subscribe(:producer, [], from, state)

      data = [
        trip = TripDescriptor.new(trip_id: "trip"),
        VehiclePosition.new(trip_id: "trip", latitude: 1, longitude: 1),
        stu = StopTimeUpdate.new(trip_id: "trip")
      ]

      expected = [{trip, [], [stu]}]
      {:noreply, [], state} = handle_events([data], from, state)
      {:noreply, events, _state} = handle_info(:timeout, state)
      assert events == [expected]
    end

    test "removes empty results post-filter" do
      filter = fn {_, _, _} -> {nil, [], []} end
      from = make_from()
      {_, state, _} = init(group_filters: [filter])
      {_, state} = handle_subscribe(:producer, [], from, state)

      data = [
        TripDescriptor.new(trip_id: "trip"),
        StopTimeUpdate.new(trip_id: "trip")
      ]

      expected = []
      {:noreply, [], state} = handle_events([data], from, state)
      {:noreply, events, _state} = handle_info(:timeout, state)
      assert events == [expected]
    end

    test "allows a CANCELED TripDescriptor with no StopTimeUpdates" do
      filter = fn group -> group end
      from = make_from()
      {_, state, _} = init(group_filters: [filter])
      {_, state} = handle_subscribe(:producer, [], from, state)

      data = [
        trip = TripDescriptor.new(trip_id: "trip", schedule_relationship: :CANCELED)
      ]

      expected = [{trip, [], []}]
      {:noreply, [], state} = handle_events([data], from, state)
      {:noreply, events, _state} = handle_info(:timeout, state)
      assert events == [expected]
    end

    test "when Logging debug messages, does not crash" do
      log_level = Logger.level()

      on_exit(fn ->
        Logger.configure(level: log_level)
      end)

      Logger.configure(level: :debug)
      data = []

      events = [data]
      filters = []
      from = make_from()
      {_, state, _} = init(filters: filters)
      {_, state} = handle_subscribe(:producer, [], from, state)
      {:noreply, [], state} = handle_events(events, from, state)

      log =
        capture_log(fn ->
          handle_info(:timeout, state)
        end)

      refute log == ""
    end

    property "with multiple sources, returns the merged data" do
      check all(multi_source_mergeables <- list_of_mergeables()) do
        {_, state, _} = init([])

        expected =
          multi_source_mergeables
          |> List.flatten()
          |> Merge.merge()
          |> GTFSRealtimeHelpers.group()

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

  describe "handle_info/2" do
    @tag :capture_log
    test "ignores unknown messages" do
      assert handle_info(:unknown, :state) == {:noreply, [], :state}
    end
  end

  defp make_from do
    {self(), make_ref()}
  end

  defp list_of_mergeables do
    list_of(list_of_vehicles(), min_length: 1, max_length: 3)
  end

  defp list_of_vehicles do
    gen all(vehicles <- list_of(vehicle())) do
      Enum.uniq_by(vehicles, &VehiclePosition.id/1)
    end
  end

  defp vehicle do
    gen all(
          last_updated <- StreamData.positive_integer(),
          vehicle_id <- StreamData.string(:ascii)
        ) do
      VehiclePosition.new(
        id: vehicle_id,
        last_updated: last_updated,
        latitude: 1.0,
        longitude: 1.0
      )
    end
  end

  defp clear_mailbox do
    receive do
      _ -> clear_mailbox()
    after
      0 -> :ok
    end
  end
end
