defmodule Concentrate.GTFS.PickupDropOff do
  @moduledoc """
  Server which knows whether riders can be picked up or dropped off at a stop.
  """
  use GenStage
  alias Concentrate.GTFS.Helpers
  require Logger
  import :binary, only: [copy: 1]
  @table __MODULE__

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec pickup_drop_off(String.t(), String.t() | non_neg_integer) :: {boolean, boolean} | :unknown
  def pickup_drop_off(trip_id, stop_or_stop_sequence) when is_binary(trip_id) do
    find_value({trip_id, stop_or_stop_sequence})
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
    @table = :ets.new(@table, [:named_table, :public, :set])
    {:consumer, [], opts}
  end

  @impl GenStage
  def handle_events(events, _from, state) do
    count =
      events
      |> List.flatten()
      |> Stream.flat_map(fn
        {"stop_times.txt", body} ->
          Helpers.io_stream(body)

        _ ->
          []
      end)
      |> CSV.decode(headers: true, num_workers: System.schedulers())
      |> Stream.flat_map(&build_inserts/1)
      |> Enum.reduce(0, fn insert, acc ->
        if acc == 0 do
          true = :ets.delete_all_objects(@table)
        end

        :ets.insert(@table, insert)
        acc + 1
      end)

    _ =
      if count > 0 do
        Logger.info(fn ->
          "#{__MODULE__}: updated with #{count} records"
        end)
      end

    {:noreply, [], state, :hibernate}
  end

  defp can_pickup_drop_off?("1"), do: false
  defp can_pickup_drop_off?(_), do: true

  defp build_inserts({:error, _}) do
    []
  end

  defp build_inserts({:ok, row}) do
    trip_id = copy(Map.get(row, "trip_id"))
    stop_id = copy(Map.get(row, "stop_id"))
    stop_sequence = String.to_integer(Map.get(row, "stop_sequence"))

    pickup? = can_pickup_drop_off?(Map.get(row, "pickup_type"))
    drop_off? = can_pickup_drop_off?(Map.get(row, "drop_off_type"))

    for stop_key <- [stop_id, stop_sequence] do
      {{trip_id, stop_key}, {pickup?, drop_off?}}
    end
  end
end
