defmodule Concentrate.GroupFilter.CancelledTrip do
  @moduledoc """
  Cancels TripUpdates and and skips StopTimeUpdates for cancelled trips.
  """
  @behaviour Concentrate.GroupFilter
  alias Concentrate.Filter.Alert.CancelledTrips
  alias Concentrate.{StopTimeUpdate, TripDescriptor}

  @impl Concentrate.GroupFilter
  def filter(trip_group, module \\ CancelledTrips)

  def filter({%TripDescriptor{} = td, _vps, [stu | _]} = group, module) do
    trip_id = TripDescriptor.trip_id(td)
    route_id = TripDescriptor.route_id(td)
    time = StopTimeUpdate.time(stu)

    cond do
      TripDescriptor.schedule_relationship(td) == :CANCELED ->
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

  def filter(other, _module), do: other

  defp cancel_group({td, vps, stus}) do
    td = TripDescriptor.cancel(td)
    stus = Enum.map(stus, &StopTimeUpdate.skip/1)
    {td, vps, stus}
  end
end
