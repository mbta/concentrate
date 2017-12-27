defmodule Concentrate.Filter.RemoveUnneededTimesTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Concentrate.Filter.RemoveUnneededTimes
  alias Concentrate.StopTimeUpdate

  defmodule FakeSequence do
    @moduledoc "Fake implementation of Filter.GTFS.FirstLastStopSequence"
    def stop_sequences("trip"), do: {1, 5}
    def stop_sequences(_), do: nil
  end

  @state __MODULE__.FakeSequence
  @arrival_time DateTime.from_unix!(5)
  @departure_time DateTime.from_unix!(500)
  @stu StopTimeUpdate.new(
         trip_id: "trip",
         arrival_time: @arrival_time,
         departure_time: @departure_time
       )

  describe "filter/2" do
    test "a stop time update with a different stop_sequence isn't modified" do
      stu = @stu
      assert {:cont, ^stu, _} = filter(stu, @state)
    end

    test "the arrival_time is removed from the first stop sequence" do
      stu = StopTimeUpdate.update(@stu, stop_sequence: 1)
      expected = StopTimeUpdate.update(stu, arrival_time: nil)
      assert {:cont, ^expected, _} = filter(stu, @state)
    end

    test "the departure_time is removed from the last stop sequence" do
      stu = StopTimeUpdate.update(@stu, stop_sequence: 5)
      expected = StopTimeUpdate.update(stu, departure_time: nil)
      assert {:cont, ^expected, _} = filter(stu, @state)
    end

    test "if the departure time is missing from the first stop, use the arrival time" do
      stu = StopTimeUpdate.update(@stu, stop_sequence: 1, departure_time: nil)
      expected = StopTimeUpdate.update(stu, arrival_time: nil, departure_time: @arrival_time)
      assert {:cont, ^expected, _} = filter(stu, @state)
    end

    test "if the arrival time is missing from the last stop, use the departure time" do
      stu = StopTimeUpdate.update(@stu, stop_sequence: 5, arrival_time: nil)
      expected = StopTimeUpdate.update(stu, arrival_time: @departure_time, departure_time: nil)
      assert {:cont, ^expected, _} = filter(stu, @state)
    end

    test "other stop sequence values are left alone" do
      stu = StopTimeUpdate.update(@stu, stop_sequence: 3)
      assert {:cont, ^stu, _} = filter(stu, @state)
    end

    test "other values are returned as-is" do
      assert {:cont, :value, _} = filter(:value, @state)
    end
  end
end
