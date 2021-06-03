defmodule Concentrate.Filter.NullStopSequenceTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Filter.NullStopSequence
  alias Concentrate.StopTimeUpdate

  describe "filter/1" do
    test "skips a stop time update with a null stop_sequence" do
      stu = StopTimeUpdate.new(stop_sequence: nil)
      assert :skip = filter(stu)
    end

    test "passes through a stop time update with a stop_sequence" do
      stu = StopTimeUpdate.new(stop_sequence: 1)
      assert {:cont, ^stu} = filter(stu)
    end

    test "passes through other values" do
      assert {:cont, :value} = filter(:value)
    end
  end
end
