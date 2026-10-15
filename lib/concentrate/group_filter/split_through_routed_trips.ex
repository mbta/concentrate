defmodule Concentrate.GroupFilter.SplitThroughRoutedTrips do
  @moduledoc """
  Splits updates for through-routed trips into updates for their component trips.
  """
  @behaviour Concentrate.GroupFilter
  alias Concentrate.Encoder.TripGroup
  alias Concentrate.GTFS.{SplitTrips, StopTimes}
  alias Concentrate.{StopTimeUpdate, TripDescriptor, VehiclePosition}

  @impl Concentrate.GroupFilter
  def filter(
        trip_group,
        split_trips \\ SplitTrips,
        stop_times \\ StopTimes
      )

  def filter(
        %TripGroup{td: %TripDescriptor{} = td} = group,
        split_trips,
        stop_times
      ) do
    trip_id = TripDescriptor.trip_id(td)

    case split_trips.trip_ids(trip_id) do
      [_ | _] = trip_ids -> Enum.map(trip_ids, &make_split_trip(group, &1, stop_times))
      nil -> group
    end
  end

  defp make_split_trip(
         %TripGroup{td: td, vps: vps, stus: stus} = group,
         trip_id,
         stop_times
       ) do
    stop_seqs =
      stop_times.stops_for_trip(trip_id) |> Enum.map(&elem(&1, 0))

    %TripGroup{
      group
      | td: TripDescriptor.update_trip_id(td, trip_id),
        vps:
          vps
          |> Enum.filter(&(VehiclePosition.stop_sequence(&1) in stop_seqs))
          |> Enum.map(&VehiclePosition.update_trip_id(&1, trip_id)),
        stus:
          stus
          |> Enum.filter(&(StopTimeUpdate.stop_sequence(&1) in stop_seqs))
          |> Enum.map(&StopTimeUpdate.update_trip_id(&1, trip_id))
    }
  end
end
