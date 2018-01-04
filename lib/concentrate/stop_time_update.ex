defmodule Concentrate.StopTimeUpdate do
  @moduledoc """
  Structure for representing an update to a StopTime (e.g. a predicted arrival or departure)
  """
  import Concentrate.StructHelpers

  defstruct_accessors([
    :trip_id,
    :stop_id,
    :arrival_time,
    :departure_time,
    :stop_sequence,
    :status,
    :track,
    schedule_relationship: :SCHEDULED
  ])

  @doc """
  Marks the update as skipped (when the stop is closed, for example).
  """
  @spec skip(%__MODULE__{}) :: t
  def skip(%__MODULE__{} = stu) do
    %{stu | schedule_relationship: :SKIPPED, arrival_time: nil, departure_time: nil}
  end

  defimpl Concentrate.Mergeable do
    def key(%{trip_id: trip_id, stop_id: stop_id, stop_sequence: stop_sequence}) do
      {trip_id, stop_id, stop_sequence}
    end

    def merge(first, second) do
      @for.new(
        trip_id: first.trip_id,
        stop_id: first.stop_id,
        stop_sequence: first.stop_sequence,
        arrival_time: time(:lt, first.arrival_time, second.arrival_time),
        departure_time: time(:gt, first.departure_time, second.departure_time),
        status: first.status || second.status,
        track: first.track || second.track,
        schedule_relationship:
          if first.schedule_relationship == :SCHEDULED do
            second.schedule_relationship
          else
            first.schedule_relationship
          end
      )
    end

    defp time(_, nil, time), do: time
    defp time(_, time, nil), do: time

    defp time(best_comparison, first, second) do
      if DateTime.compare(first, second) == best_comparison do
        first
      else
        second
      end
    end
  end
end
