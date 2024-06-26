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
    :update_type,
    last_trip: false,
    revenue: true,
    schedule_relationship: :SCHEDULED
  ])

  def timestamp_truncated(%__MODULE__{timestamp: number}) when is_integer(number) do
    number
  end

  def timestamp_truncated(%__MODULE__{timestamp: number}) when is_float(number) do
    trunc(number)
  end

  def timestamp_truncated(%__MODULE__{timestamp: nil}) do
    nil
  end

  def cancel(trip_update) do
    # single L
    %{trip_update | schedule_relationship: :CANCELED}
  end

  defimpl Concentrate.Mergeable do
    def key(%{trip_id: trip_id}), do: trip_id

    def related_keys(_), do: []

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
          timestamp: first.timestamp || second.timestamp,
          last_trip: first.last_trip || second.last_trip,
          schedule_relationship: merge_schedule_relationship(first, second),
          update_type: merge_update_type(first.update_type, second.update_type)
      }
    end

    defp merge_schedule_relationship(%{schedule_relationship: :SCHEDULED}, second),
      do: second.schedule_relationship

    defp merge_schedule_relationship(first, _), do: first.schedule_relationship

    defp merge_update_type(nil, second), do: second
    defp merge_update_type(first, _), do: first
  end
end
