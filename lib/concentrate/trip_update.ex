defmodule Concentrate.TripUpdate do
  @moduledoc """
  TripUpdate represents a (potential) change to a GTFS trip.
  """
  defstruct [
    :trip_id,
    :route_id,
    :direction_id,
    :start_date,
    :start_time,
    schedule_relationship: :SCHEDULED
  ]

  @opaque t :: %__MODULE__{}

  @doc """
  Builds a TripUpdate from keyword arguments.
  """
  def new(opts) when is_list(opts) do
    struct!(__MODULE__, opts)
  end

  @doc false
  def trip_id(%__MODULE__{trip_id: trip_id}), do: trip_id

  @doc false
  def route_id(%__MODULE__{route_id: route_id}), do: route_id

  @doc false
  def direction_id(%__MODULE__{direction_id: direction_id}), do: direction_id

  @doc false
  def start_time(%__MODULE__{start_time: start_time}), do: start_time

  @doc false
  def start_date(%__MODULE__{start_date: start_date}), do: start_date

  @doc false
  def schedule_relationship(%__MODULE__{schedule_relationship: schedule_relationship}) do
    schedule_relationship
  end

  defimpl Concentrate.Mergeable do
    def key(%{trip_id: trip_id}), do: trip_id

    def merge(first, second) do
      @for.new(
        trip_id: first.trip_id,
        route_id: first.route_id || second.route_id,
        direction_id: first.direction_id || second.direction_id,
        start_date: first.start_date || second.start_date,
        start_time: first.start_time || second.start_time,
        schedule_relationship:
          if first.schedule_relationship == :SCHEDULED do
            second.schedule_relationship
          else
            first.schedule_relationship
          end
      )
    end
  end
end
