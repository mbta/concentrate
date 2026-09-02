defmodule Concentrate.GroupFilter.CancelledTrip do
  @moduledoc """
  Cancels TripUpdates and and skips StopTimeUpdates for cancelled trips.
  """
  @behaviour Concentrate.GroupFilter
  alias Concentrate.Encoder.TripGroup
  alias Concentrate.Filter.Alert.CancelledTrips
  alias Concentrate.GTFS.{Routes, StopTimes, Trips}
  alias Concentrate.{StopTimeUpdate, TripDescriptor}

  require Logger

  @impl Concentrate.GroupFilter
  def filter(
        trip_group,
        module \\ CancelledTrips,
        routes_module \\ Routes,
        gtfs_stop_times \\ StopTimes,
        trips_module \\ Trips,
        now_fn \\ &now/0
      )

  def filter(
        %TripGroup{td: %TripDescriptor{} = td, stus: stop_time_updates} = group,
        module,
        routes_module,
        gtfs_stop_times,
        trips_module,
        now_fn
      ) do
    trip_id = TripDescriptor.trip_id(td)
    route_id = TripDescriptor.route_id(td)

    time = maybe_time(stop_time_updates)

    cond do
      TripDescriptor.schedule_relationship(td) == :CANCELED ->
        cancel_group(group, gtfs_stop_times)

      bus_block_waiver?(
        td,
        stop_time_updates,
        gtfs_stop_times,
        now_fn,
        routes_module.route_type(route_id)
      ) ->
        group = remap_school_trip(trips_module, group)
        cancel_group(group, gtfs_stop_times)

      is_nil(time) ->
        group

      is_binary(trip_id) and module.trip_cancelled?(trip_id, time) ->
        cancel_group(group, gtfs_stop_times)

      is_binary(route_id) and module.route_cancelled?(route_id, time) ->
        cancel_group(group, gtfs_stop_times)

      true ->
        group
    end
  end

  def filter(
        %TripGroup{} = other,
        _module,
        _trips_module,
        _gtfs_stop_times,
        _trips_module,
        _now_fn
      ),
      do: other

  defp maybe_time([stu | _]) do
    StopTimeUpdate.time(stu)
  end

  defp maybe_time(_) do
    nil
  end

  defp bus_block_waiver?(td, [_ | _] = stop_time_updates, gtfs_stop_times, now_fn, 3) do
    if Enum.all?(stop_time_updates, &StopTimeUpdate.skipped?(&1)) do
      trip_id = TripDescriptor.trip_id(td)
      trip_date = TripDescriptor.start_date(td)
      now = now_fn.()

      future_scheduled_stops_for_trip =
        future_scheduled_stops_for_trip(trip_id, trip_date, now, gtfs_stop_times) || []

      all_stu_stops_and_stop_sequences =
        MapSet.new(stop_time_updates, fn stu ->
          {StopTimeUpdate.stop_id(stu), StopTimeUpdate.stop_sequence(stu)}
        end)

      Enum.all?(future_scheduled_stops_for_trip, fn {stop_sequence, stop_id, _, _} ->
        {stop_id, stop_sequence} in all_stu_stops_and_stop_sequences
      end)
    else
      false
    end
  end

  defp bus_block_waiver?(_, _, _, _, _), do: false

  defp remap_school_trip(trips_module, %TripGroup{td: td} = tg) do
    trip_id = TripDescriptor.trip_id(td)

    if not trips_module.exists?(trip_id) do
      do_remap_school_trip(trips_module, trip_id)
    else
    end
  end

  defp do_remap_school_trip(trips_module, %TripGroup{td: td} = group) do
  end

  defp cancel_group(%TripGroup{td: td, stus: []} = group, gtfs_stop_times) do
    td = TripDescriptor.cancel(td)
    trip_id = TripDescriptor.trip_id(td)

    stops_for_trip = gtfs_stop_times.stops_for_trip(trip_id)

    stus =
      case stops_for_trip do
        [_ | _] ->
          Enum.map(stops_for_trip, fn
            {stop_sequence, stop_id} ->
              StopTimeUpdate.new(
                trip_id: trip_id,
                stop_sequence: stop_sequence,
                stop_id: stop_id,
                schedule_relationship: :SKIPPED
              )
          end)

        :unknown ->
          []
      end

    %{group | td: td, stus: stus}
  end

  defp cancel_group(%TripGroup{td: td, stus: stus} = group, _) do
    td = TripDescriptor.cancel(td)
    stus = Enum.map(stus, &StopTimeUpdate.skip/1)
    %{group | td: td, stus: stus}
  end

  defp now do
    System.system_time(:second)
  end

  defp future_scheduled_stops_for_trip(trip_id, trip_date, now, gtfs_stop_times) do
    case gtfs_stop_times.stops_for_trip_with_arrival_departure(trip_id, trip_date) do
      :unknown ->
        nil

      stops_for_trip ->
        Enum.reject(stops_for_trip, &nil_or_past_arrival_departure?(&1, now))
    end
  end

  defp nil_or_past_arrival_departure?(stop_time, now) do
    if is_nil(stop_time) do
      true
    else
      {_, _, arrival, departure} = stop_time

      now > (arrival || departure)
    end
  end
end
