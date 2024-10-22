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
    :passthrough_time,
    :stop_sequence,
    :status,
    :track,
    :platform_id,
    :uncertainty,
    schedule_relationship: :SCHEDULED
  ])

  @doc """
  Returns a time for the StopTimeUpdate: arrival if present, otherwise departure.
  """
  @spec time(%__MODULE__{}) :: non_neg_integer | nil
  def time(%__MODULE__{arrival_time: time}) when is_integer(time), do: time
  def time(%__MODULE__{departure_time: time}), do: time

  @compile inline: [time: 1]

  @doc """
  Marks the update as skipped (when the stop is closed, for example).
  """
  @spec skip(%__MODULE__{}) :: t
  def skip(%__MODULE__{} = stu) do
    %{stu | schedule_relationship: :SKIPPED, arrival_time: nil, departure_time: nil, status: nil}
  end

  @spec skipped?(%__MODULE__{}) :: boolean()
  def skipped?(%__MODULE__{schedule_relationship: schedule_relationship}) do
    schedule_relationship == :SKIPPED
  end

  defimpl Concentrate.Mergeable do
    require Logger

    def key(%{trip_id: trip_id, stop_sequence: stop_sequence}), do: {trip_id, stop_sequence}

    def related_keys(_), do: []

    def merge(first, second) do
      time_stu =
        if Concentrate.StopTimeUpdate.time(first) <= Concentrate.StopTimeUpdate.time(second),
          do: first,
          else: second

      %{
        first
        | arrival_time: time_stu.arrival_time,
          departure_time: time_stu.departure_time,
          passthrough_time: first.passthrough_time || second.passthrough_time,
          status: first.status || second.status,
          track: first.track || second.track,
          schedule_relationship:
            if first.schedule_relationship == :SCHEDULED do
              second.schedule_relationship
            else
              first.schedule_relationship
            end,
          stop_id: max(first.stop_id, second.stop_id),
          platform_id: first.platform_id || second.platform_id,
          uncertainty: first.uncertainty || second.uncertainty
      }
    end
  end
end
