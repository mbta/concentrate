defmodule Concentrate.Encoder.GTFSRealtimeGroup do
  @moduledoc false
  alias Concentrate.{TripUpdate, VehiclePosition, StopTimeUpdate}

  @doc """
  Given a list of parsed data, returns a list of tuples:

  {TripUpdate.t() | nil, [VehiclePosition.t()], [StopTimeUpdate.t]}

  The VehiclePositions/StopTimeUpdates will share the same trip ID.
  """
  def group(parsed) do
    mapping = Enum.reduce(parsed, %{}, &group_by_trip_id/2)
    # we sort by the initial size, which keeps the trip updates in their original ordering
    for {_, {tu, vps, stus, _}} <- Enum.sort_by(mapping, &elem(elem(&1, 1), 3)) do
      {tu, Enum.reverse(vps), Enum.reverse(stus)}
    end
  end

  defp group_by_trip_id(%TripUpdate{} = tu, map) do
    case TripUpdate.trip_id(tu) do
      nil ->
        map

      id ->
        Map.update(map, id, {tu, [], [], map_size(map)}, fn {_, vps, stus, size} ->
          {tu, vps, stus, size}
        end)
    end
  end

  defp group_by_trip_id(%VehiclePosition{} = vp, map) do
    trip_id = VehiclePosition.trip_id(vp)

    Map.update(map, trip_id, {nil, [vp], [], map_size(map)}, fn {tu, vps, stus, size} ->
      {tu, [vp | vps], stus, size}
    end)
  end

  defp group_by_trip_id(%StopTimeUpdate{} = stu, map) do
    trip_id = StopTimeUpdate.trip_id(stu)

    Map.update(map, trip_id, {nil, [], [stu], map_size(map)}, fn {tu, vps, stus, size} ->
      {tu, vps, [stu | stus], size}
    end)
  end
end
