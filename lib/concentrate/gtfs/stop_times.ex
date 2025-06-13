defmodule Concentrate.GTFS.StopTimes do
  @moduledoc """
  Server which stores data related to GTFS stop times, keyed by trip ID and stop sequence.
  """
  use GenStage
  alias Concentrate.GTFS.Helpers
  require Logger
  import :binary, only: [copy: 1]
  @table __MODULE__

  # Arrival and departure are stored as an offset in seconds from noon local time, as per GTFS:
  # https://gtfs.org/schedule/reference/#field-types

  @type object_key :: {trip_id :: String.t(), stop_sequence :: non_neg_integer}
  @type object_value :: {
          stop_id :: String.t(),
          arrival_offset :: integer,
          departure_offset :: integer,
          time_zone_name :: String.t(),
          pick_up? :: boolean,
          drop_off? :: boolean
        }

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Given a trip ID, stop sequence, and reference date, returns the scheduled arrival and departure
  times for the trip at the stop on the date, as Unix timestamps. (Assumes the given trip runs on
  the given date; this is not actually checked against the calendar.)
  """
  @spec arrival_departure(String.t(), non_neg_integer, :calendar.date()) ::
          {arrival_time :: non_neg_integer, departure_time :: non_neg_integer} | :unknown
  def arrival_departure(trip_id, stop_sequence, {_, _, _} = date)
      when is_binary(trip_id) and is_integer(stop_sequence) do
    case lookup({trip_id, stop_sequence}) do
      {_, arrival, departure, time_zone, _, _} ->
        {to_unix!(date, arrival, time_zone), to_unix!(date, departure, time_zone)}

      nil ->
        :unknown
    end
  end

  @doc "Returns whether riders can be picked up or dropped off for a given stop time."
  @spec pick_up_drop_off(String.t(), non_neg_integer) :: {boolean, boolean} | :unknown
  def pick_up_drop_off(trip_id, stop_sequence)
      when is_binary(trip_id) and is_integer(stop_sequence) do
    case lookup({trip_id, stop_sequence}) do
      {_, _, _, _, pick_up?, drop_off?} -> {pick_up?, drop_off?}
      nil -> :unknown
    end
  end

  @doc "Returns the stop ID for a stop time, identified by trip ID and stop sequence."
  @spec stop_id(String.t(), non_neg_integer) :: String.t() | :unknown
  def stop_id(trip_id, stop_sequence) when is_binary(trip_id) and is_integer(stop_sequence) do
    case lookup({trip_id, stop_sequence}) do
      {stop_id, _, _, _, _, _} -> stop_id
      nil -> :unknown
    end
  end

  @spec lookup(object_key) :: object_value | nil
  defp lookup(key) do
    :ets.lookup_element(@table, key, 2)
  rescue
    ArgumentError -> nil
  end

  # Note: we assume, as GTFS does, that 12:00:00 always occurs exactly once per day regardless of
  # time change rules.
  defp to_unix!({year, month, day}, offset, zone) do
    {:ok, noon} = NaiveDateTime.new(year, month, day, 12, 0, 0)
    (noon |> DateTime.from_naive!(zone) |> DateTime.to_unix()) + offset
  end

  @impl GenStage
  def init(opts) do
    @table = :ets.new(@table, [:named_table, :public, :set])
    {:consumer, [], opts}
  end

  @impl GenStage
  def handle_events(events, _from, state) do
    events |> List.flatten() |> Map.new() |> handle_files()
    {:noreply, [], state, :hibernate}
  end

  defp handle_files(%{
         "agency.txt" => agencies,
         "routes.txt" => routes,
         "stop_times.txt" => stop_times,
         "trips.txt" => trips
       }) do
    trip_time_zones = trip_time_zones(agencies, routes, trips)
    inserts = stop_times_inserts(stop_times, trip_time_zones)
    true = :ets.delete_all_objects(@table)
    :ets.insert(@table, inserts)

    if inserts != [] do
      Logger.info(fn -> "#{__MODULE__}: updated with #{length(inserts)} records" end)
    end
  end

  defp handle_files(_), do: nil

  # Determine the time zone that each trip's stop times should be interpreted in.
  defp trip_time_zones(agencies, routes, trips) do
    agency_time_zones = csv_into_map(agencies, &{&1["agency_id"], copy(&1["agency_timezone"])})
    route_time_zones = csv_into_map(routes, &{&1["route_id"], agency_time_zones[&1["agency_id"]]})
    csv_into_map(trips, &{&1["trip_id"], route_time_zones[&1["route_id"]]})
  end

  defp csv_into_map(csv, func) do
    csv
    |> Helpers.io_stream()
    |> CSV.decode(headers: true)
    |> Stream.flat_map(fn
      {:ok, row} -> [func.(row)]
      {:error, _} -> []
    end)
    |> Enum.into(%{})
  end

  defp stop_times_inserts(stop_times, trip_time_zones) do
    stop_times
    |> Helpers.io_stream()
    |> CSV.decode(headers: true, num_workers: System.schedulers())
    |> Enum.flat_map(fn
      {:ok, %{"trip_id" => trip_id} = row} -> build_inserts(row, trip_time_zones[trip_id])
      {:error, _} -> []
    end)
  end

  defp build_inserts(row, time_zone) when is_binary(time_zone) do
    trip_id = copy(row["trip_id"])
    stop_sequence = String.to_integer(row["stop_sequence"])

    stop_id = copy(row["stop_id"])
    arrival = time_to_offset(row["arrival_time"])
    departure = time_to_offset(row["departure_time"])
    pick_up? = type_to_boolean(row["pickup_type"])
    drop_off? = type_to_boolean(row["drop_off_type"])

    [{{trip_id, stop_sequence}, {stop_id, arrival, departure, time_zone, pick_up?, drop_off?}}]
  end

  defp build_inserts(_, _), do: []

  @twelve_hours 12 * 60 * 60

  # Convert a GTFS "time" to an offset in seconds from noon, which as per the spec is what GTFS
  # times actually mean (rather, they are an "offset from 12 hours before noon"; we pre-subtract
  # the 12-hour offset as well).
  defp time_to_offset(
         <<hour::binary-size(2), ":", minute::binary-size(2), ":", second::binary-size(2)>>
       ) do
    String.to_integer(hour) * 60 * 60 +
      String.to_integer(minute) * 60 +
      String.to_integer(second) -
      @twelve_hours
  end

  defp time_to_offset(
         <<_hour::binary-size(1), ":", _min::binary-size(2), ":", _sec::binary-size(2)>> = time
       ) do
    time_to_offset("0" <> time)
  end

  defp type_to_boolean("1"), do: false
  defp type_to_boolean(_), do: true
end
