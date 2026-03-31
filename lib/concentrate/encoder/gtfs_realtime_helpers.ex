defmodule Concentrate.Encoder.GTFSRealtimeHelpers do
  @moduledoc """
  Helper functions for encoding GTFS-Realtime files.
  """
  alias Concentrate.Encoder.TripGroup
  alias Concentrate.{StopTimeUpdate, TripDescriptor, VehiclePosition}
  import Calendar.ISO, only: [date_to_string: 4]

  @doc """
  Given a list of parsed data, returns a list of TripGroups, one for each
  trip ID.
  """
  @spec group([TripDescriptor.t() | VehiclePosition.t() | StopTimeUpdate.t()]) :: [TripGroup.t()]
  def group(parsed) do
    # we sort by the initial size, which keeps the trip updates in their original ordering
    parsed
    |> Enum.reduce(%{}, &group_by_trip_id/2)
    |> Map.values()
    |> Enum.flat_map(fn
      # Drop groups with no info besides the trip descriptor, unless the trip is
      # CANCELED.
      %TripGroup{td: %TripDescriptor{} = td, vps: [], stus: []} = trip_group ->
        if TripDescriptor.schedule_relationship(td) == :CANCELED do
          [trip_group]
        else
          []
        end

      %TripGroup{stus: stus} = trip_group ->
        sorted_stus = Enum.sort_by(stus, &StopTimeUpdate.stop_sequence/1)
        [%{trip_group | stus: sorted_stus}]
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
  def feed_header(opts \\ []) do
    timestamp = trunc(Keyword.get(opts, :timestamp) || :erlang.system_time(:seconds))

    %{
      gtfs_realtime_version: "2.0",
      timestamp: timestamp,
      incrementality: if(Keyword.get(opts, :partial?), do: :DIFFERENTIAL, else: :FULL_DATASET)
    }
  end

  @doc """
  Builds a list of TripDescriptor FeedEntities.

  Takes a function to turn a StopTimeUpdate struct into the GTFS-RT version.
  """
  @spec trip_update_feed_entity(
          [TripGroup.t()],
          (StopTimeUpdate.t() -> map() | :skip),
          (TripDescriptor.t() -> map() | :skip)
        ) :: [map()]
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

  @doc """
  Renders the `stop_time_properties` field.

  If `assigned_stop_id` is nil, render `stop_time_properties` as nil, otherwise
  render `assigned_stop_id` as a field of `stop_time_properties`.
  """
  def stop_time_properties(nil), do: nil

  def stop_time_properties(assigned_stop_id) do
    %{
      assigned_stop_id: assigned_stop_id
    }
  end

  @doc """
  Returns true if the group is non-revenue
  """
  def non_revenue?(%TripGroup{td: td}) do
    td && not td.revenue
  end

  defp group_by_trip_id(%TripDescriptor{} = td, map) do
    if trip_id = TripDescriptor.trip_id(td) do
      default = %TripGroup{td: td}
      Map.update(map, trip_id, default, &add_trip_descriptor(&1, td))
    else
      map
    end
  end

  defp group_by_trip_id(%VehiclePosition{} = vp, map) do
    trip_id = VehiclePosition.trip_id(vp)
    default = %TripGroup{vps: [vp]}
    Map.update(map, trip_id, default, &add_vehicle_position(&1, vp))
  end

  defp group_by_trip_id(%StopTimeUpdate{} = stu, map) do
    trip_id = StopTimeUpdate.trip_id(stu)
    default = %TripGroup{stus: [stu]}
    Map.update(map, trip_id, default, &add_stop_time_update(&1, stu))
  end

  defp add_trip_descriptor(trip_group, td) do
    %{trip_group | td: td}
  end

  defp add_vehicle_position(%TripGroup{vps: vps} = trip_group, vp) do
    %{trip_group | vps: [vp | vps]}
  end

  defp add_stop_time_update(%TripGroup{stus: stus} = trip_group, stu) do
    %{trip_group | stus: [stu | stus]}
  end

  defp build_trip_update_entity(
         %TripGroup{td: %TripDescriptor{} = td, vps: vps, stus: stus},
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

    timestamp = TripDescriptor.timestamp_truncated(td)

    trip =
      trip_data
      |> Map.merge(enhanced_data_fn.(td))
      |> drop_nil_values()

    {update_type, trip} = Map.pop(trip, :update_type)

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
                timestamp: timestamp,
                update_type: update_type
              })
          }
        ]

      TripDescriptor.schedule_relationship(td) == :CANCELED ->
        [
          %{
            id: id,
            trip_update:
              drop_nil_values(%{
                trip: trip,
                vehicle: vehicle,
                timestamp: timestamp,
                update_type: update_type
              })
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
