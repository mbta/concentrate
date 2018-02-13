defmodule Concentrate.Encoder.GTFSRealtimeHelpers do
  @moduledoc """
  Helper functions for encoding GTFS-Realtime files.
  """
  alias Concentrate.{TripUpdate, VehiclePosition, StopTimeUpdate}
  import Calendar.ISO, only: [date_to_iso8601: 4]

  @doc """
  Given a list of parsed data, returns a list of tuples:

  {TripUpdate.t() | nil, [VehiclePosition.t()], [StopTimeUpdate.t]}

  The VehiclePositions/StopTimeUpdates will share the same trip ID.
  """
  def group(parsed) do
    # we sort by the initial size, which keeps the trip updates in their original ordering
    parsed
    |> Enum.reduce(%{}, &group_by_trip_id/2)
    |> Map.values()
    |> Enum.reject(&match?({_, _, [], []}, &1))
    |> Enum.sort()
    |> Enum.map(fn {_, tu, vps, stus} ->
      vps = Enum.reverse(vps)
      stus = Enum.sort_by(stus, &StopTimeUpdate.stop_sequence/1)

      {tu, vps, stus}
    end)
  end

  @doc """
  Encodes a Date into the GTFS-Realtime format YYYYMMDD.

  ## Examples

      iex> encode_date(nil)
      nil
      iex> encode_date({1970, 1, 3})
      "19700103"
  """
  def encode_date(nil) do
    nil
  end

  def encode_date({year, month, day}) do
    date_to_iso8601(year, month, day, :basic)
  end

  @doc """
  Removes nil values from a map.

  ## Examples

      iex> drop_nil_values(%{a: 1, b: nil})
      %{a: 1}
      iex> drop_nil_values(%{})
      nil
  """
  def drop_nil_values(empty) when empty == %{} do
    nil
  end

  def drop_nil_values(map) do
    :maps.fold(
      fn
        _k, nil, acc -> acc
        k, v, acc -> Map.put(acc, k, v)
      end,
      %{},
      map
    )
  end

  @doc """
  Renders the schedule relationship field.

  SCHEDULED is the default and is rendered as `nil`. Other relationships are
  rendered as-is.
  """
  def schedule_relationship(:SCHEDULED), do: nil
  def schedule_relationship(relationship), do: relationship

  defp group_by_trip_id(%TripUpdate{} = tu, map) do
    case TripUpdate.trip_id(tu) do
      nil ->
        map

      id ->
        Map.update(map, id, {map_size(map), tu, [], []}, &add_trip_update(&1, tu))
    end
  end

  defp group_by_trip_id(%VehiclePosition{} = vp, map) do
    trip_id = VehiclePosition.trip_id(vp)

    Map.update(map, trip_id, {map_size(map), nil, [vp], []}, &add_vehicle_position(&1, vp))
  end

  defp group_by_trip_id(%StopTimeUpdate{} = stu, map) do
    trip_id = StopTimeUpdate.trip_id(stu)

    Map.update(map, trip_id, {map_size(map), nil, [], [stu]}, &add_stop_time_update(&1, stu))
  end

  defp add_trip_update({size, _tu, vps, stus}, tu) do
    {size, tu, vps, stus}
  end

  defp add_vehicle_position({size, tu, vps, stus}, vp) do
    {size, tu, [vp | vps], stus}
  end

  defp add_stop_time_update({size, tu, vps, stus}, stu) do
    {size, tu, vps, [stu | stus]}
  end
end
