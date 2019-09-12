defmodule Concentrate.Filter.GTFS.StopIDs do
  @moduledoc """
  Server which knows the stop ID based on the trip ID and stop sequence.
  """
  use GenStage
  require Logger
  import :binary, only: [copy: 1]
  @table __MODULE__

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec stop_id(String.t(), non_neg_integer) :: String.t() | :unknown
  def stop_id(trip_id, stop_sequence) do
    find_value({trip_id, stop_sequence})
  end

  defp find_value(key) do
    case :ets.lookup(@table, key) do
      [{_, value}] -> value
      [] -> :unknown
    end
  rescue
    ArgumentError -> :unknown
  end

  @impl GenStage
  def init(opts) do
    :ets.new(@table, [:named_table, :public, :set])
    {:consumer, [], opts}
  end

  @impl GenStage
  def handle_events(events, _from, state) do
    count =
      events
      |> List.flatten()
      |> Stream.flat_map(fn
        {"stop_times.txt", body} ->
          io_stream(body)

        _ ->
          []
      end)
      |> CSV.decode(headers: true, num_workers: System.schedulers())
      |> Enum.reduce(0, fn row, acc ->
        if acc == 0 do
          true = :ets.delete_all_objects(@table)
        end

        :ets.insert(@table, build_insert(row))
        acc + 1
      end)

    if count > 0 do
      Logger.info(fn ->
        "#{__MODULE__}: updated with #{count} records"
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

  defp build_insert({:ok, row}) do
    trip_id = copy(Map.get(row, "trip_id"))
    stop_id = copy(Map.get(row, "stop_id"))
    stop_sequence = String.to_integer(Map.get(row, "stop_sequence"))

    {{trip_id, stop_sequence}, stop_id}
  end
end
