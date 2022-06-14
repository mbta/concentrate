defmodule Concentrate.GTFS.HelpersTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Concentrate.GTFS.Helpers

  describe "io_stream/1" do
    test "streams the lines of a binary" do
      stream = Helpers.io_stream("first line\nsecond line\nthird line")

      assert Enum.to_list(stream) == ["first line\n", "second line\n", "third line"]
    end
  end
end
