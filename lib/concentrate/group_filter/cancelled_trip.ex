defmodule Concentrate.GroupFilter.CancelledTrip do
  @moduledoc """
  Cancels TripUpdates and and skips StopTimeUpdates for cancelled trips.
  """
  @behaviour Concentrate.GroupFilter
  alias Concentrate.Filter.Alert.CancelledTrips
  alias Concentrate.GTFS.{Routes, StopTimes}
  alias Concentrate.{StopTimeUpdate, TripDescriptor}

  @impl Concentrate.GroupFilter
  def filter(
        trip_group,
        module \\ CancelledTrips,
        routes_module \\ Routes,
        gtfs_stop_times \\ StopTimes
      )

  def filter(
        {%TripDescriptor{} = td, _vps, stop_time_updates} = group,
        module,
        routes_module,
        gtfs_stop_times
      ) do
    trip_id = TripDescriptor.trip_id(td)
    route_id = TripDescriptor.route_id(td)

    time = maybe_time(stop_time_updates)

    cond do
      TripDescriptor.schedule_relationship(td) == :CANCELED ->
        cancel_group(group, gtfs_stop_times)

      bus_block_waiver?(stop_time_updates, routes_module.route_type(route_id)) ->
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

  def filter(other, _module, _trips_module, _gtfs_stop_times), do: other

  defp maybe_time([stu | _]) do
    StopTimeUpdate.time(stu)
  end

  defp maybe_time(_) do
    nil
  end

  defp bus_block_waiver?(stop_time_updates, 3) do
    Enum.all?(stop_time_updates, &StopTimeUpdate.skipped?(&1))
  end

  defp bus_block_waiver?(_, _), do: false

  defp cancel_group({td, vps, []}, gtfs_stop_times) do
    td = TripDescriptor.cancel(td)
    trip_id = TripDescriptor.trip_id(td)

    stus =
      trip_id
      |> gtfs_stop_times.stops_for_trip()
      |> Enum.map(fn {stop_sequence, stop_id} ->
        StopTimeUpdate.new(
          trip_id: trip_id,
          stop_sequence: stop_sequence,
          stop_id: stop_id,
          schedule_relationship: :SKIPPED
        )
      end)

    {td, vps, stus}
  end

  defp cancel_group({td, vps, stus}, _) do
    td = TripDescriptor.cancel(td)
    stus = Enum.map(stus, &StopTimeUpdate.skip/1)
    {td, vps, stus}
  end
end
