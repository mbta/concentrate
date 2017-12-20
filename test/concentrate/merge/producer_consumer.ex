defmodule Concentrate.Merge.ProducerConsumerTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties
  import Concentrate.Merge.ProducerConsumer
  alias Concentrate.TestMergeable

  describe "handle_events/2" do
    property "with one source, returns the original data" do
      state = init([])

      check all mergeables <- TestMergeable.mergeables() do
        {:noreply, [merged], _state} = handle_events([mergeables], :from, state)
        assert merged == mergeables
      end
    end
  end
end
