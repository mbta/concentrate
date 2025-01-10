defmodule Concentrate.GroupFilter.CancelledTrip do
  @moduledoc """
  Cancels TripUpdates and and skips StopTimeUpdates for cancelled trips.
  """
  @behaviour Concentrate.GroupFilter
  alias Concentrate.Filter.Alert.CancelledTrips
  alias Concentrate.GTFS.Routes
  alias Concentrate.{StopTimeUpdate, TripDescriptor}

  @impl Concentrate.GroupFilter
  def filter(trip_group, module \\ CancelledTrips, routes_module \\ Routes)

  def filter(
        {%TripDescriptor{} = td, _vps, [stu | _] = stop_time_updates} = group,
        module,
        routes_module
      ) do
    trip_id = TripDescriptor.trip_id(td)
    route_id = TripDescriptor.route_id(td)
    time = StopTimeUpdate.time(stu)

    cond do
      TripDescriptor.schedule_relationship(td) == :CANCELED ->
        cancel_group(group)

      bus_block_waiver?(stop_time_updates, routes_module.route_type(route_id)) ->
        cancel_group(group)

      is_nil(time) ->
        group

      is_binary(trip_id) and module.trip_cancelled?(trip_id, time) ->
        cancel_group(group)

      is_binary(route_id) and module.route_cancelled?(route_id, time) ->
        cancel_group(group)

      true ->
        group
    end
  end

  def filter(other, _module, _trips_module), do: other

  defp bus_block_waiver?(stop_time_updates, 3) do
    Enum.all?(stop_time_updates, &StopTimeUpdate.skipped?(&1))
  end

  defp bus_block_waiver?(_, _), do: false

  defp cancel_group({td, vps, stus}) do
    td = TripDescriptor.cancel(td)
    stus = Enum.map(stus, &StopTimeUpdate.skip/1)
    {td, vps, stus}
  end
end
