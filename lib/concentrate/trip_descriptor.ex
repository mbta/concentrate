defmodule Concentrate.TripDescriptor do
  @moduledoc """
  TripDescriptor represents a (potential) change to a GTFS trip.
  """
  import Concentrate.StructHelpers

  defstruct_accessors([
    :trip_id,
    :route_id,
    :route_pattern_id,
    :direction_id,
    :start_date,
    :start_time,
    :vehicle_id,
    :timestamp,
    schedule_relationship: :SCHEDULED
  ])

  def cancel(trip_update) do
    # single L
    %{trip_update | schedule_relationship: :CANCELED}
  end

  defimpl Concentrate.Mergeable do
    def key(%{trip_id: trip_id}), do: trip_id

    def merge(first, second) do
      if {first.start_date, first.start_time} > {second.start_date, second.start_time} do
        do_merge(first, second)
      else
        do_merge(second, first)
      end
    end

    def do_merge(first, second) do
      %{
        first
        | route_id: first.route_id || second.route_id,
          route_pattern_id: first.route_pattern_id || second.route_pattern_id,
          direction_id: first.direction_id || second.direction_id,
          start_date: first.start_date || second.start_date,
          start_time: first.start_time || second.start_time,
          vehicle_id: first.vehicle_id || second.vehicle_id,
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
