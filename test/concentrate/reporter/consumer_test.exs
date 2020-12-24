defmodule Concentrate.Reporter.ConsumerTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Reporter.Consumer
  import ExUnit.CaptureLog
  alias Concentrate.TripDescriptor

  defmodule FakeReporter do
    @behaviour Concentrate.Reporter

    @impl Concentrate.Reporter
    def init, do: "state"

    @impl Concentrate.Reporter
    def log(items, state) do
      output = [
        item_count: length(items),
        state: state
      ]

      {output, "more " <> state}
    end
  end

  alias __MODULE__.FakeReporter

  describe "handle_events/3" do
    test "logs the output" do
      {:consumer, state, _} = init(module: FakeReporter)
      parsed = [TripDescriptor.new([])]

      log =
        capture_log([level: :info], fn ->
          assert {:noreply, [], _} = handle_events([parsed], :from, state)
        end)

      assert log =~ "FakeReporter report"
      assert log =~ " item_count=1"
      assert log =~ ~s( state="state")
    end

    test "keeps track of previous state" do
      {:consumer, state, _} = init(module: FakeReporter)
      parsed = [TripDescriptor.new([])]
      assert {:noreply, [], state} = handle_events([parsed], :from, state)

      log =
        capture_log([level: :info], fn ->
          handle_events([parsed], :from, state)
        end)

      assert log =~ ~s(state="more state")
    end
  end
end
