defmodule Concentrate.SourceReporter.BasicTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.SourceReporter.Basic

  describe "log/2" do
    test "logs basic stats" do
      state = init()

      update =
        Concentrate.FeedUpdate.new(
          url: "url",
          updates: [1, 2, 3]
        )

      assert {[count: 3, partial?: false], _state} = log(update, state)
    end
  end
end
