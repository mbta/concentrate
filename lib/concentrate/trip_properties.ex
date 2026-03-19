defmodule Concentrate.TripProperties do
  @moduledoc """
  TripProperties represents updated properties of a GTFS trip. This struct
  mirrors a subset of the TripProperties message in gtfs-realtime.proto.
  """
  import Concentrate.StructHelpers

  defstruct_accessors([
    :trip_id,
    :start_date,
    :start_time,
    :shape_id,
    :trip_headsign,
    :trip_short_name
  ])

  @doc """
  Creates a new struct instance by pulling each field's value from the
  same-named field in the proto. Missing fields get `nil`.
  """
  def new_from_proto(%{} = proto) do
    # Pull each field's value from the same-named field in the proto.
    new(
      Enum.map(
        ~w(trip_id start_date start_time shape_id trip_headsign trip_short_name)a,
        fn field -> {field, proto[field]} end
      )
    )
  end

  @doc """
  Creates a new struct instance by pulling each field's value from the
  same-named field in a JSON map. Missing fields get `nil`.
  """
  def new_from_json(%{} = json) do
    # Pull each field's value from the same-named field in the proto.
    new(
      Enum.map(
        ~w(trip_id start_date start_time shape_id trip_headsign trip_short_name)a,
        fn field -> {field, json[to_string(field)]} end
      )
    )
  end

  defimpl Concentrate.Mergeable do
    def key(%{trip_id: trip_id}), do: trip_id

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
