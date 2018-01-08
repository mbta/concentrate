defmodule Concentrate.TripUpdate do
  @moduledoc """
  TripUpdate represents a (potential) change to a GTFS trip.
  """
  import Concentrate.StructHelpers

  defstruct_accessors([
    :trip_id,
    :route_id,
    :direction_id,
    :start_date,
    :start_time,
    schedule_relationship: :SCHEDULED
  ])

  defimpl Concentrate.Mergeable do
    def key(%{trip_id: trip_id}), do: trip_id

    def merge(first, second) do
      %{
        first
        | route_id: first.route_id || second.route_id,
          direction_id: first.direction_id || second.direction_id,
          start_date: first.start_date || second.start_date,
          start_time: first.start_time || second.start_time,
          schedule_relationship:
            if first.schedule_relationship == :SCHEDULED do
              second.schedule_relationship
            else
              first.schedule_relationship
            end
      }
    end
  end
end
