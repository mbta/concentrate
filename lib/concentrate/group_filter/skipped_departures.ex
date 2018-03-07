defmodule Concentrate.GroupFilter.SkippedDepartures do
  @moduledoc """
  Ensures that we have correct departure times in the presence of SKIPPED
  stops.

  The last stop on a trip should not have a departure time. If the end of the
  trip is SKIPPED, the last actual stop has no departure.
  """
  @behaviour Concentrate.GroupFilter
  alias Concentrate.StopTimeUpdate

  def filter({trip_update, vehicle_positions, stop_time_updates}) do
    reverse_updates = Enum.reverse(stop_time_updates)

    last_index =
      Enum.find_index(reverse_updates, &(StopTimeUpdate.schedule_relationship(&1) != :SKIPPED))

    new_updates =
      if last_index do
        reverse_updates
        |> List.update_at(last_index, &StopTimeUpdate.update_departure_time(&1, nil))
        |> Enum.reverse()
      else
        stop_time_updates
      end

    {trip_update, vehicle_positions, new_updates}
  end
end
