defmodule Concentrate.Filter.GTFS.FirstLastStopSequence do
  @moduledoc """
  Server which maintains a list of trip -> {first_stop_sequence, last_stop_sequence} mappings.
  """
  use GenStage
  require Logger
  import :binary, only: [copy: 1]
  @table __MODULE__

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec stop_sequences(String.t()) :: {non_neg_integer, non_neg_integer} | nil
  def stop_sequences(trip_id) when is_binary(trip_id) do
    case :ets.match(@table, {trip_id, :"$1"}) do
      [[sequences]] -> sequences
      [] -> nil
    end
  end

  @spec pickup?(String.t(), String.t() | non_neg_integer) :: boolean
  def pickup?(trip_id, stop_or_stop_sequence) when is_binary(trip_id) do
    key = {:no_pickup, trip_id, stop_or_stop_sequence}
    not :ets.member(@table, key)
  end

  @spec drop_off?(String.t(), String.t() | non_neg_integer) :: boolean
  def drop_off?(trip_id, stop_or_stop_sequence) when is_binary(trip_id) do
    key = {:no_drop_off, trip_id, stop_or_stop_sequence}
    not :ets.member(@table, key)
  end

  @impl GenStage
  def init(opts) do
    :ets.new(@table, [:named_table, :public, :duplicate_bag, {:read_concurrency, true}])
    {:consumer, [], opts}
  end

  @impl GenStage
  def handle_events(events, _from, state) do
    inserts =
      events
      |> List.flatten()
      |> Stream.flat_map(fn
        {"stop_times.txt", body} ->
          io_stream(body)

        _ ->
          []
      end)
      |> CSV.decode(headers: true, num_workers: System.schedulers())
      |> Stream.flat_map(fn
        {:ok, row} ->
          [
            {
              copy(row["trip_id"]),
              copy(row["stop_id"]),
              String.to_integer(row["stop_sequence"]),
              can_pickup_drop_off?(row["pickup_type"]),
              can_pickup_drop_off?(row["drop_off_type"])
            }
          ]

        {:error, _} ->
          []
      end)
      |> Enum.reduce(%{}, &group_by_first_last/2)

    _ =
      if inserts == %{} do
        :ok
      else
        true = :ets.delete_all_objects(@table)
        :ets.insert(@table, Enum.into(inserts, []))

        Logger.info(fn ->
          "#{__MODULE__}: updated with #{map_size(inserts)} records"
        end)
      end

    {:noreply, [], state, :hibernate}
  end

  @spec io_stream(binary) :: Enumerable.t()
  defp io_stream(body) when is_binary(body) do
    # turns the given binary into a Stream of lines.
    Stream.resource(
      fn ->
        {:ok, pid} = StringIO.open(body)
        pid
      end,
      fn pid ->
        case IO.read(pid, :line) do
          line when is_binary(line) -> {[line], pid}
          _ -> {:halt, pid}
        end
      end,
      fn pid ->
        StringIO.close(pid)
      end
    )
  end

  defp can_pickup_drop_off?("1"), do: false
  defp can_pickup_drop_off?(_), do: true

  defp group_by_first_last({trip_id, stop_id, stop_sequence, can_pickup?, can_drop_off?}, acc) do
    acc =
      Map.update(acc, trip_id, {stop_sequence, stop_sequence}, fn {first, last} = existing ->
        cond do
          stop_sequence < first ->
            {stop_sequence, last}

          stop_sequence > last ->
            {first, stop_sequence}

          true ->
            existing
        end
      end)

    acc =
      if can_pickup? do
        acc
      else
        acc
        |> Map.put({:no_pickup, trip_id, stop_id}, [])
        |> Map.put({:no_pickup, trip_id, stop_sequence}, [])
      end

    if can_drop_off? do
      acc
    else
      acc
      |> Map.put({:no_drop_off, trip_id, stop_id}, [])
      |> Map.put({:no_drop_off, trip_id, stop_sequence}, [])
    end
  end
end
