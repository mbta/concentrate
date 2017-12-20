defmodule Concentrate.Merge.ProducerConsumerTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties
  import Concentrate.Merge.ProducerConsumer
  alias Concentrate.{Merge, TestMergeable}

  describe "handle_events/2" do
    property "with one source, returns the latest data, merged" do
      check all all_mergeables <- list_of_mergeables() do
        {_, state, _} = init([])
        expected = Merge.merge(List.last(all_mergeables))

        assert {:noreply, [^expected], _state} = handle_events(all_mergeables, :from, state)
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

        assert {:noreply, [^expected], _state} =
                 Enum.reduce(multi_source_mergeables, acc, fn mergeables, {_, _, state} ->
                   from = make_ref()
                   handle_events([mergeables], from, state)
                 end)
      end
    end

    property "updating a source returns the latest data for that source" do
      check all all_mergeables <- list_of_mergeables() do
        {_, state, _} = init([])
        expected = Merge.merge(List.last(all_mergeables))

        acc = {:noreply, [], state}

        assert {:noreply, [^expected], _} =
                 Enum.reduce(all_mergeables, acc, fn mergeables, {_, _, state} ->
                   handle_events([mergeables], :from, state)
                 end)
      end
    end
  end

  defp list_of_mergeables do
    list_of(TestMergeable.mergeables(), min_length: 1, max_length: 3)
  end
end
