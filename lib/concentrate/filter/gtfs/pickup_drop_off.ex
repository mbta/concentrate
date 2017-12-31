defmodule Concentrate.Filter.GTFS.PickupDropOff do
  @moduledoc """
  Server which knows whether riders can be picked up or dropped off at a stop.
  """
  use GenStage
  require Logger
  import :binary, only: [copy: 1]
  @table __MODULE__

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
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
      |> Enum.flat_map(&build_inserts/1)

    _ =
      unless inserts == [] do
        true = :ets.delete_all_objects(@table)
        :ets.insert(@table, inserts)

        Logger.info(fn ->
          "#{__MODULE__}: updated with #{length(inserts)} records"
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

  defp build_inserts({trip_id, stop_id, stop_sequence, can_pickup?, can_drop_off?}) do
    inserts =
      if can_pickup? do
        []
      else
        [
          {{:no_pickup, trip_id, stop_id}},
          {{:no_pickup, trip_id, stop_sequence}}
        ]
      end

    if can_drop_off? do
      inserts
    else
      [
        {{:no_drop_off, trip_id, stop_id}},
        {{:no_drop_off, trip_id, stop_sequence}}
        | inserts
      ]
    end
  end
end
