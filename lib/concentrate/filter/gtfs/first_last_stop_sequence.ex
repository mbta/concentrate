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
  def stop_sequences(trip_id) do
    case :ets.match(@table, {trip_id, :"$1"}) do
      [[sequences]] -> sequences
      [] -> nil
    end
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
          [{copy(row["trip_id"]), String.to_integer(row["stop_sequence"])}]

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

  defp group_by_first_last({trip_id, stop_sequence}, acc) do
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
  end
end
