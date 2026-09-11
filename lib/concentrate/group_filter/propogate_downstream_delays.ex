defmodule Concentrate.GroupFilter.PropogateDownstreamDelays do
  @moduledoc """
  If the first stop of a CR trip has a delaying status, generate StopTimeUpdates
  for any following stop on the trip has an arrival time in the past and doesn't
  already have a StopTimeUpdate.
  """
  alias Concentrate.Encoder.TripGroup
  alias Concentrate.GTFS.{Routes, StopTimes}
  alias Concentrate.{StopTimeUpdate, TripDescriptor}

  @behaviour Concentrate.GroupFilter

  @matching_statuses Enum.map(
                       Application.compile_env(
                         :concentrate,
                         [:group_filters, __MODULE__, :matching_statuses],
                         []
                       ),
                       &String.downcase/1
                     )
  @downstream_status Application.compile_env(
                       :concentrate,
                       [:group_filters, __MODULE__, :downstream_status],
                       "Delayed"
                     )

  @impl Concentrate.GroupFilter
  def filter(
        %TripGroup{td: %TripDescriptor{} = td, stus: stus} = group,
        stop_time_module \\ StopTimes,
        routes_module \\ Routes,
        now_fn \\ &now/0
      ) do
    route_id = TripDescriptor.route_id(td)

    if routes_module.route_type(route_id) != 2 ||
         TripDescriptor.schedule_relationship(td) != :SCHEDULED do
      group
    else
      trip_id = TripDescriptor.trip_id(td)
      trip_date = TripDescriptor.start_date(td)

      stus = propogate_delayed_status(trip_id, trip_date, stus, stop_time_module, now_fn.())
      %{group | stus: stus}
    end
  end

  defp now do
    System.system_time(:second)
  end

  defp propogate_delayed_status(trip_id, trip_date, stus, stop_time_module, now) do
    scheduled_stop_times =
      stop_time_module.stops_for_trip_with_arrival_departure(trip_id, trip_date)

    first_status_only_stu = first_status_only_stu(stus)

    if first_status_only_stu != nil do
      add_missing_delayed_stus(
        trip_id,
        first_status_only_stu.stop_sequence,
        stus,
        scheduled_stop_times,
        now
      )
    else
      stus
    end
  end

  defp add_missing_delayed_stus(trip_id, first_stop_sequence, stus, scheduled_stop_times, now) do
    stop_sequence_to_stu = Map.new(stus, &{&1.stop_sequence, &1})

    Enum.flat_map(scheduled_stop_times, fn scheduled_stop_time ->
      {stop_sequence, stop_id, _arrival, departure} = scheduled_stop_time
      existing_stu = Map.get(stop_sequence_to_stu, stop_sequence)

      cond do
        existing_stu != nil ->
          [existing_stu]

        !is_nil(departure) && now > departure && stop_sequence > first_stop_sequence ->
          [
            StopTimeUpdate.new(
              trip_id: trip_id,
              stop_sequence: stop_sequence,
              stop_id: stop_id,
              status: @downstream_status
            )
          ]

        true ->
          []
      end
    end)
  end

  @spec first_status_only_stu([StopTimeUpdate.t()]) :: StopTimeUpdate.t() | nil
  defp first_status_only_stu(stus) do
    Enum.find(stus, fn stu ->
      String.downcase(stu.status) in @matching_statuses &&
        stu.arrival_time == nil &&
        stu.departure_time == nil
    end)
  end
end
