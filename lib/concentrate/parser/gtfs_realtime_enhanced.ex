defmodule Concentrate.Parser.GTFSRealtimeEnhanced do
  @moduledoc """
  Parser for GTFS-RT enhanced JSON files.
  """
  @behaviour Concentrate.Parser
  require Logger
  alias Concentrate.{TripUpdate, StopTimeUpdate, Alert, Alert.InformedEntity}

  @default_active_period [%{"start" => nil, "end" => nil}]

  @impl Concentrate.Parser
  def parse(binary) when is_binary(binary) do
    for {:ok, json} <- [Poison.decode(binary)],
        entity <- Map.get(json, "entity", []),
        decoded <- decode_feed_entity(entity) do
      decoded
    end
  end

  defp decode_feed_entity(%{"trip_update" => trip_update}) do
    decode_trip_update(trip_update)
  end

  defp decode_feed_entity(%{"id" => id, "alert" => alert}) do
    [
      Alert.new(
        id: id,
        effect: alert_effect(alert["effect"]),
        active_period:
          Enum.map(alert["active_period"] || @default_active_period, &decode_active_period/1),
        informed_entity: Enum.map(alert["informed_entity"] || [], &decode_informed_entity/1)
      )
    ]
  end

  defp decode_feed_entity(_) do
    []
  end

  def decode_trip_update(trip_update) do
    tu = decode_trip_descriptor(trip_update["trip"])

    stop_updates =
      for stu <- trip_update["stop_time_update"] do
        StopTimeUpdate.new(
          trip_id: if(trip_update["trip"], do: optional_copy(trip_update["trip"]["trip_id"])),
          stop_id: optional_copy(stu["stop_id"]),
          stop_sequence: stu["stop_sequence"],
          schedule_relationship: schedule_relationship(stu["schedule_relationship"]),
          arrival_time: time_from_event(stu["arrival"]),
          departure_time: time_from_event(stu["departure"]),
          status: boarding_status(stu["boarding_status"])
        )
      end

    tu ++ stop_updates
  end

  defp optional_copy(binary) when is_binary(binary), do: :binary.copy(binary)
  defp optional_copy(nil), do: nil

  defp decode_trip_descriptor(nil) do
    []
  end

  defp decode_trip_descriptor(trip) do
    [
      TripUpdate.new(
        trip_id: optional_copy(trip["trip_id"]),
        route_id: optional_copy(trip["route_id"]),
        direction_id: trip["direction_id"],
        start_date: optional_copy(trip["start_date"]),
        start_time: optional_copy(trip["start_time"]),
        schedule_relationship: schedule_relationship(trip["schedule_relationship"])
      )
    ]
  end

  defp time_from_event(nil), do: nil
  defp time_from_event(%{"time" => nil}), do: nil
  defp time_from_event(%{"time" => time}), do: DateTime.from_unix!(time)

  defp schedule_relationship(nil), do: nil

  for relationship <- ~w(SCHEDULED)a do
    defp schedule_relationship(unquote(Atom.to_string(relationship))), do: unquote(relationship)
  end

  defp boarding_status(nil), do: nil

  for status <- ~w(ON_TIME DELAYED ARRIVING NOW_BOARDING ALL_ABOARD DEPARTED LATE)a do
    defp boarding_status(unquote(Atom.to_string(status))), do: unquote(status)
  end

  defp boarding_status(unknown) do
    Logger.error(fn ->
      "#{__MODULE__}: unknown boarding status #{inspect(unknown)}"
    end)

    nil
  end

  for effect <- ~w(
        NO_SERVICE
        REDUCED_SERVICE
        SIGNIFICANT_DELAYS
        DETOUR
        ADDITIONAL_SERVICE
        MODIFIED_SERVICE
        OTHER_EFFECT
        UNKNOWN_EFFECT
        STOP_MOVED)a do
    defp alert_effect(unquote(Atom.to_string(effect))), do: unquote(effect)
  end

  defp alert_effect(other) do
    Logger.error(fn ->
      "#{__MODULE__}: unknown alert effect #{inspect(other)}"
    end)

    :UNKNOWN_EFFECT
  end

  defp decode_active_period(map) do
    start = DateTime.from_unix!(map["start"] || 0)

    stop =
      DateTime.from_unix!(
        if stop = map["end"] do
          stop
        else
          # 2 ^ 32 - 1
          4_294_967_295
        end
      )

    {start, stop}
  end

  defp decode_informed_entity(map) do
    trip = map["trip"] || %{}

    InformedEntity.new(
      trip_id: trip["id"],
      route_id: map["route_id"],
      direction_id: trip["direction_id"],
      route_type: map["route_type"],
      stop_id: map["stop_id"],
      activities: map["activities"] || []
    )
  end
end
