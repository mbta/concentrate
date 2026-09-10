defmodule Concentrate.GroupFilter.PropogateDelayedStatus do
  @moduledoc """
  If the first stop of a CR trip has a delaying status, generate StopTimeUpdates
  for any following stop on the trip has an arrival time in the past and doesn't
  already have a StopTimeUpdate.
  """
  alias Concentrate.Encoder.TripGroup
  alias Concentrate.GTFS.{Routes, StopTimes}
  alias Concentrate.{StopTimeUpdate, TripDescriptor}
  @behaviour Concentrate.GroupFilter

  # TODO: make this environment config and use actual status values
  @first_stop_delaying_statuses ["Delayed"]
  @delayed_status "Delayed"

  @impl Concentrate.GroupFilter
  def filter(
        %TripGroup{td: %TripDescriptor{} = td, stus: stus} = group,
        stop_times \\ StopTimes,
        routes_module \\ Routes,
        now_fn \\ &now/0
      ) do
    route_id = TripDescriptor.route_id(td)

    if !(routes_module.route_type(route_id) == 2 &&
           TripDescriptor.schedule_relationship(td) == :SCHEDULED) do
      group
    else
      trip_id = TripDescriptor.trip_id(td)
      trip_date = TripDescriptor.start_date(td)

      stus = propogate_delayed_status(trip_id, trip_date, stus, stop_times, now_fn.())
      %{group | stus: stus}
    end
  end

  defp now do
    System.system_time(:second)
  end

  defp propogate_delayed_status(trip_id, trip_date, stus, stop_times, now) do
    [first_stu | _rest_stus] = stus

    scheduled_stop_times = stop_times.stops_for_trip_with_arrival_departure(trip_id, trip_date)

    if first_stop_delayed?(first_stu, scheduled_stop_times) do
      add_missing_delayed_stus(
        TripDescriptor.trip_id(first_stu.td),
        stus,
        scheduled_stop_times,
        now
      )
    else
      stus
    end
  end

  defp add_missing_delayed_stus(trip_id, stus, scheduled_stop_times, now) do
    stop_sequence_to_stu = Map.new(stus, &{&1.stop_sequence, &1})

    Enum.flat_map(scheduled_stop_times, fn scheduled_stop_time ->
      {stop_sequence, stop_id, arrival, _departure} = scheduled_stop_time
      existing_stu = Map.get(stop_sequence_to_stu, stop_sequence)

      cond do
        existing_stu != nil ->
          [existing_stu]

        !is_nil(arrival) && now > arrival ->
          [
            StopTimeUpdate.new(
              trip_id: trip_id,
              stop_sequence: stop_sequence,
              stop_id: stop_id,
              status: @delayed_status
            )
          ]

        true ->
          []
      end
    end)
  end

  defp first_stop_delayed?(first_stu, [first_scheduled_stop | _rest]) do
    {stop_sequence, _stop_id, _arrival, _departure} = first_scheduled_stop

    first_stu.stop_sequence == stop_sequence &&
      first_stu.status in @first_stop_delaying_statuses
  end

  defp first_stop_delayed?(_first_stu, _scheduled_stop_times), do: false
end
