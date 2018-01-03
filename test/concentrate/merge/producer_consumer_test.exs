defmodule Concentrate.Merge.ProducerConsumerTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties
  import Concentrate.Merge.ProducerConsumer
  alias Concentrate.{Merge, TestMergeable}

  describe "handle_events/2" do
    test "schedules a timeout" do
      {_, state, _} = init(timeout: 100)
      {:noreply, [], state} = handle_events([1, 2, 3], :from, state)
      assert state.timer
      refute_received :timeout
      {:noreply, [], _state} = handle_events([4, 5, 6], :from, state)
      assert_receive :timeout, 500
    end

    property "with one source, returns the latest data, merged" do
      check all all_mergeables <- list_of_mergeables() do
        {_, state, _} = init([])
        expected = Merge.merge(List.last(all_mergeables))

        assert {:noreply, [], state} = handle_events(all_mergeables, :from, state)
        assert {:noreply, [^expected], _} = handle_info(:timeout, state)
      end
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
            from = make_ref()
            handle_events([mergeables], from, state)
          end)

        {:noreply, [actual], _state} = handle_info(:timeout, state)

        assert Enum.sort(actual) == Enum.sort(expected)
      end
    end

    property "updating a source returns the latest data for that source" do
      check all all_mergeables <- list_of_mergeables() do
        {_, state, _} = init([])
        expected = Merge.merge(List.last(all_mergeables))

        acc = {:noreply, [], state}

        {:noreply, [], state} =
          Enum.reduce(all_mergeables, acc, fn mergeables, {_, _, state} ->
            handle_events([mergeables], :from, state)
          end)

        assert {:noreply, [^expected], _} = handle_info(:timeout, state)
      end
    end
  end

  defp list_of_mergeables do
    list_of(TestMergeable.mergeables(), min_length: 1, max_length: 3)
  end
end
