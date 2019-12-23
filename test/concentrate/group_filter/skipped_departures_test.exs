defmodule Concentrate.GroupFilter.SkippedDeparturesTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties
  import Concentrate.GroupFilter.SkippedDepartures
  alias Concentrate.StopTimeUpdate

  describe "filter/1" do
    property "the last non-skipped stop has no departure time" do
      check all(updates <- list_of(stop_time_update(), min_length: 5)) do
        group = {nil, [], updates}
        {_, _, new_updates} = filter(group)

        if StopTimeUpdate.schedule_relationship(Enum.at(updates, -1)) == :SKIPPED do
          last_departure =
            new_updates
            |> Enum.reverse()
            |> Enum.find(&(StopTimeUpdate.schedule_relationship(&1) != :SKIPPED))

          if last_departure do
            refute(StopTimeUpdate.departure_time(last_departure))
          else
            assert Enum.all?(updates, &(StopTimeUpdate.schedule_relationship(&1) == :SKIPPED))
          end
        else
          assert new_updates == updates
        end
      end
    end

    test "keeps stops in the same order" do
      group = {
        nil,
        [],
        [
          StopTimeUpdate.new(stop_sequence: 1, departure_time: 1),
          StopTimeUpdate.new(stop_sequence: 2, departure_time: 2),
          StopTimeUpdate.new(stop_sequence: 3, departure_time: 3),
          StopTimeUpdate.new(stop_sequence: 4, schedule_relationship: :SKIPPED),
          StopTimeUpdate.new(stop_sequence: 5, schedule_relationship: :SKIPPED)
        ]
      }

      {_, _, new_updates} = filter(group)
      assert Enum.map(new_updates, &StopTimeUpdate.stop_sequence/1) == [1, 2, 3, 4, 5]
    end

    test "if no stops are skipped, returns the same data" do
      group = {nil, [], [StopTimeUpdate.new(departure_time: 9)]}
      assert filter(group) == group
    end
  end

  defp stop_time_update do
    gen all(
          schedule_relationship <- one_of(~w(SCHEDULED SKIPPED)a),
          departure_time <- time_if_scheduled(schedule_relationship)
        ) do
      StopTimeUpdate.new(
        schedule_relationship: schedule_relationship,
        departure_time: departure_time
      )
    end
  end

  defp time_if_scheduled(:SCHEDULED), do: positive_integer()
  defp time_if_scheduled(_), do: constant(nil)
end
