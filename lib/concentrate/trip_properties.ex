defmodule Concentrate.TripProperties do
  @moduledoc """
  TripProperties represents updated properties of a GTFS trip. This struct
  mirrors a subset of the TripProperties message in gtfs-realtime.proto.
  """
  import Concentrate.StructHelpers

  defstruct_accessors([
    # The trip_id associated with these updated properties. In GTFS-RT, this
    # value is stored in the parent message, but in Concentrate we need to carry
    # it here too, so that a TripProperties value can be grouped with related
    # updates for the same trip_id.
    :source_trip_id,
    # The trip_id for a new trip that is a duplicate of one defined in the
    # schedule. GTFS-RT calls this field TripProperties.trip_id; our name is
    # different to avoid confusion with :source_trip_id.
    :new_trip_id,
    :start_date,
    :start_time,
    :shape_id,
    :trip_headsign,
    :trip_short_name
  ])

  @doc """
  Creates a new struct instance by pulling each field's value from the
  equivalent field in the proto. Missing fields get `nil`. Argument `trip_id`
  is the ID of the trip to which this `TripProperties` update applies (that is,
  the trip ID for the parent `TripUpdate`).
  """
  def new_from_proto(%{} = proto, trip_id) do
    # Pull each field's value from the same-named field in the proto.
    new(
      [{:source_trip_id, trip_id}, {:new_trip_id, proto[:trip_id]}] ++
        Enum.map(
          ~w(start_date start_time shape_id trip_headsign trip_short_name)a,
          fn field -> {field, proto[field]} end
        )
    )
  end

  def new_from_proto(_, _), do: nil

  @doc """
  Creates a new struct instance by pulling each field's value from the
  equivalent field in a JSON map. Missing fields get `nil`. Argument `trip_id`
  is the ID of the trip to which this `TripProperties` update applies (that is,
  the trip ID for the parent `TripUpdate`).
  """
  def new_from_json(%{} = json, trip_id) do
    # Pull each field's value from the same-named field in the proto.
    new(
      [{:source_trip_id, trip_id}, {:new_trip_id, json["trip_id"]}] ++
        Enum.map(
          ~w(start_date start_time shape_id trip_headsign trip_short_name)a,
          fn field -> {field, json[to_string(field)]} end
        )
    )
  end

  def new_from_json(_, _), do: nil

  defimpl Concentrate.Mergeable do
    def key(%{source_trip_id: trip_id}), do: trip_id

    def related_keys(_), do: []

    def merge(first, second) do
      if {first.start_date, first.start_time} > {second.start_date, second.start_time} do
        do_merge(first, second)
      else
        do_merge(second, first)
      end
    end

    defp do_merge(first, second) do
      %{
        first
        | start_date: first.start_date || second.start_date,
          start_time: first.start_time || second.start_time,
          shape_id: first.shape_id || second.shape_id,
          trip_headsign: first.trip_headsign || second.trip_headsign,
          trip_short_name: first.trip_short_name || second.trip_short_name
      }
    end
  end
end
