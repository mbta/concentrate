defmodule Concentrate.GTFS.StopIDs do
  @moduledoc """
  Server which knows the stop ID for a given trip ID and stop sequence.
  """
  use GenStage
  alias Concentrate.GTFS.Helpers
  require Logger
  import :binary, only: [copy: 1]
  @table __MODULE__

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec stop_id(String.t(), non_neg_integer) :: String.t() | :unknown
  def stop_id(trip_id, stop_sequence) do
    case :ets.lookup(@table, {trip_id, stop_sequence}) do
      [{_, value}] -> value
      [] -> :unknown
    end
  rescue
    ArgumentError -> :unknown
  end

  @impl GenStage
  def init(opts) do
    @table = :ets.new(@table, [:named_table, :public, :set])
    {:consumer, [], opts}
  end

  @impl GenStage
  def handle_events(events, _from, state) do
    inserts =
      events
      |> List.flatten()
      |> Stream.flat_map(fn
        {"stop_times.txt", body} ->
          Helpers.io_stream(body)

        _ ->
          []
      end)
      |> CSV.decode(headers: true, num_workers: System.schedulers())
      |> Enum.map(&build_insert/1)

    if inserts != [] do
      true = :ets.delete_all_objects(@table)
      :ets.insert(@table, inserts)

      Logger.info(fn ->
        "#{__MODULE__}: updated with #{length(inserts)} records"
      end)
    end

    {:noreply, [], state, :hibernate}
  end

  defp build_insert({:ok, row}) do
    trip_id = copy(Map.get(row, "trip_id"))
    stop_id = copy(Map.get(row, "stop_id"))
    stop_sequence = String.to_integer(Map.get(row, "stop_sequence"))

    {{trip_id, stop_sequence}, stop_id}
  end
end
