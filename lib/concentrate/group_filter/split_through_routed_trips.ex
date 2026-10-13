defmodule Concentrate.GroupFilter.SplitThroughRoutedTrips do
  @moduledoc """
  Splits updates for through-routed trips into updates for their component trips.
  """
  @behaviour Concentrate.GroupFilter
  alias Concentrate.Encoder.TripGroup
  alias Concentrate.GTFS.SplitTrips
  alias Concentrate.{StopTimeUpdate, TripDescriptor, VehiclePosition}

  @impl Concentrate.GroupFilter
  def filter(
        trip_group,
        split_trips \\ SplitTrips
      )

  def filter(
        %TripGroup{td: %TripDescriptor{} = td} = group,
        split_trips
      ) do
    trip_id = TripDescriptor.trip_id(td)

    case split_trips.trip_ids(trip_id) do
      [_ | _] = trip_ids -> Enum.map(trip_ids, &set_trip_id(group, &1))
      nil -> group
    end
  end

  defp set_trip_id(
         %TripGroup{td: td, vps: vps, stus: stus} = group,
         trip_id
       ) do
    %TripGroup{
      group
      | td: TripDescriptor.update_trip_id(td, trip_id),
        vps: Enum.map(vps, &VehiclePosition.update_trip_id(&1, trip_id)),
        stus: Enum.map(stus, &StopTimeUpdate.update_trip_id(&1, trip_id))
    }
  end
end
