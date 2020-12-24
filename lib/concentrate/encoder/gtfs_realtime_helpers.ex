defmodule Concentrate.Encoder.GTFSRealtimeHelpers do
  @moduledoc """
  Helper functions for encoding GTFS-Realtime files.
  """
  alias Concentrate.{StopTimeUpdate, TripDescriptor, VehiclePosition}
  import Calendar.ISO, only: [date_to_string: 4]

  @type trip_group :: {TripDescriptor.t() | nil, [VehiclePosition.t()], [StopTimeUpdate.t()]}

  @doc """
  Given a list of parsed data, returns a list of tuples:

  {TripDescriptor.t() | nil, [VehiclePosition.t()], [StopTimeUpdate.t]}

  The VehiclePositions/StopTimeUpdates will share the same trip ID.
  """
  @spec group([TripDescriptor.t() | VehiclePosition.t() | StopTimeUpdate.t()]) :: [trip_group]
  def group(parsed) do
    # we sort by the initial size, which keeps the trip updates in their original ordering
    parsed
    |> Enum.reduce(%{}, &group_by_trip_id/2)
    |> Map.values()
    |> Enum.flat_map(fn
      {%TripDescriptor{} = td, [], []} ->
        if TripDescriptor.schedule_relationship(td) == :CANCELED do
          [{td, [], []}]
        else
          []
        end

      {td, vps, stus} ->
        stus = Enum.sort_by(stus, &StopTimeUpdate.stop_sequence/1)
        [{td, vps, stus}]
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
    date_to_string(year, month, day, :basic)
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
      timestamp: timestamp,
      incrementality: :FULL_DATASET
    }
  end

  @doc """
  Builds a list of TripDescriptor FeedEntities.

  Takes a function to turn a StopTimeUpdate struct into the GTFS-RT version.
  """
  def trip_update_feed_entity(groups, stop_time_update_fn, enhanced_data_fn \\ fn _ -> %{} end) do
    Enum.flat_map(groups, &build_trip_update_entity(&1, stop_time_update_fn, enhanced_data_fn))
  end

  @doc """
  Convert a Unix timestamp in a GTFS-RT StopTimeEvent.

  ## Examples

      iex> stop_time_event(123)
      %{time: 123}
      iex> stop_time_event(nil)
      nil
      iex> stop_time_event(123, 300)
      %{time: 123, uncertainty: 300}
  """
  def stop_time_event(time, uncertainty \\ nil)

  def stop_time_event(nil, _) do
    nil
  end

  def stop_time_event(unix_timestamp, uncertainty)
      when is_integer(uncertainty) and uncertainty > 0 do
    %{
      time: unix_timestamp,
      uncertainty: uncertainty
    }
  end

  def stop_time_event(unix_timestamp, _) do
    %{
      time: unix_timestamp
    }
  end

  @doc """
  Renders the schedule relationship field.

  SCHEDULED is the default and is rendered as `nil`. Other relationships are
  rendered as-is.
  """
  def schedule_relationship(:SCHEDULED), do: nil
  def schedule_relationship(relationship), do: relationship

  defp group_by_trip_id(%TripDescriptor{} = td, map) do
    if trip_id = TripDescriptor.trip_id(td) do
      Map.update(map, trip_id, {td, [], []}, &add_trip_descriptor(&1, td))
    else
      map
    end
  end

  defp group_by_trip_id(%VehiclePosition{} = vp, map) do
    trip_id = VehiclePosition.trip_id(vp)

    Map.update(map, trip_id, {nil, [vp], []}, &add_vehicle_position(&1, vp))
  end

  defp group_by_trip_id(%StopTimeUpdate{} = stu, map) do
    trip_id = StopTimeUpdate.trip_id(stu)

    Map.update(map, trip_id, {nil, [], [stu]}, &add_stop_time_update(&1, stu))
  end

  defp add_trip_descriptor({_td, vps, stus}, td) do
    {td, vps, stus}
  end

  defp add_vehicle_position({td, vps, stus}, vp) do
    {td, [vp | vps], stus}
  end

  defp add_stop_time_update({td, vps, stus}, stu) do
    {td, vps, [stu | stus]}
  end

  defp build_trip_update_entity(
         {%TripDescriptor{} = td, vps, stus},
         stop_time_update_fn,
         enhanced_data_fn
       ) do
    trip_id = TripDescriptor.trip_id(td)
    id = trip_id || "#{:erlang.phash2(td)}"

    trip_data = %{
      trip_id: trip_id,
      route_id: TripDescriptor.route_id(td),
      direction_id: TripDescriptor.direction_id(td),
      start_time: TripDescriptor.start_time(td),
      start_date: encode_date(TripDescriptor.start_date(td)),
      schedule_relationship: schedule_relationship(TripDescriptor.schedule_relationship(td))
    }

    timestamp = TripDescriptor.timestamp(td)

    trip =
      trip_data
      |> Map.merge(enhanced_data_fn.(td))
      |> drop_nil_values()

    vehicle = trip_update_vehicle(td, vps)

    stop_time_update =
      case stus do
        [_ | _] -> render_stop_time_updates(stus, stop_time_update_fn)
        [] -> nil
      end

    cond do
      match?([_ | _], stop_time_update) ->
        [
          %{
            id: id,
            trip_update:
              drop_nil_values(%{
                trip: trip,
                stop_time_update: stop_time_update,
                vehicle: vehicle,
                timestamp: timestamp
              })
          }
        ]

      TripDescriptor.schedule_relationship(td) == :CANCELED ->
        [
          %{
            id: id,
            trip_update: drop_nil_values(%{trip: trip, vehicle: vehicle, timestamp: timestamp})
          }
        ]

      true ->
        []
    end
  end

  defp build_trip_update_entity(_, _, _) do
    []
  end

  defp render_stop_time_updates(stus, stop_time_update_fn) do
    Enum.flat_map(stus, fn stu ->
      case stop_time_update_fn.(stu) do
        :skip ->
          []

        update ->
          [update]
      end
    end)
  end

  defp trip_update_vehicle(_update, [vp | _]) do
    drop_nil_values(%{
      id: VehiclePosition.id(vp),
      label: VehiclePosition.label(vp),
      license_plate: VehiclePosition.license_plate(vp)
    })
  end

  defp trip_update_vehicle(update, []) do
    if vehicle_id = TripDescriptor.vehicle_id(update) do
      %{id: vehicle_id}
    else
      nil
    end
  end
end
