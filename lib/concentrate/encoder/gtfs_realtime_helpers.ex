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
  Header values for a GTFS-RT feed.
  """
  def feed_header do
    timestamp = :erlang.system_time(:seconds)

    %{
      gtfs_realtime_version: "2.0",
      timestamp: timestamp
    }
  end

  @doc """
  Builds a list of TripUpdate FeedEntities.

  Takes a function to turn a StopTimeUpdate struct into the GTFS-RT version.
  """
  def trip_update_feed_entity(list, stop_time_update_fn) do
    list
    |> group
    |> Enum.flat_map(&build_trip_update_entity(&1, stop_time_update_fn))
  end

  @doc """
  Convert a Unix timestamp in a GTFS-RT StopTimeEvent.

  ## Examples

      iex> stop_time_event(123)
      %{time: 123}
      iex> stop_time_event(nil)
      nil
  """
  def stop_time_event(nil) do
    nil
  end

  def stop_time_event(unix_timestamp) do
    %{
      time: unix_timestamp
    }
  end

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
    if trip_id = StopTimeUpdate.trip_id(stu) do
      Map.update(map, trip_id, {map_size(map), nil, [], [stu]}, &add_stop_time_update(&1, stu))
    else
      map
    end
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

  defp build_trip_update_entity({update, _vps, [_ | _] = stus}, stop_time_update_fn) do
    trip_id = TripUpdate.trip_id(update)

    [
      %{
        id: trip_id,
        trip_update: %{
          trip:
            drop_nil_values(%{
              trip_id: trip_id,
              route_id: TripUpdate.route_id(update),
              direction_id: TripUpdate.direction_id(update),
              start_time: TripUpdate.start_time(update),
              start_date: encode_date(TripUpdate.start_date(update)),
              schedule_relationship: TripUpdate.schedule_relationship(update)
            }),
          stop_time_update: Enum.map(stus, stop_time_update_fn)
        }
      }
    ]
  end

  defp build_trip_update_entity(_, _) do
    []
  end
end
