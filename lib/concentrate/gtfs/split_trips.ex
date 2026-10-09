defmodule Concentrate.GTFS.SplitTrips do
  @moduledoc """
  Server which maintains a list of multi-route trips which have been split into multiple GTFS trips.
  """
  use GenStage
  require Logger
  import :binary, only: [copy: 1]
  @table __MODULE__

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def trip_ids(multi_trip_id) do
    :ets.lookup_element(@table, multi_trip_id, 2)
  rescue
    ArgumentError -> nil
  end

  def init(opts) do
    @table = :ets.new(@table, [:named_table, :public, :bag])
    {:consumer, %{}, opts}
  end

  def handle_events(events, _from, state) do
    trip_ids =
      for event <- events,
          {"trips.txt", trip_body} <- event,
          {:ok, row} <- String.split(trip_body, "\n") |> CSV.decode(headers: true) do
        copy(row["trip_id"])
      end

    inserts =
      trip_ids
      |> Enum.flat_map(fn trip_id ->
        case String.split(trip_id, "_", parts: 2) do
          [multi_trip_id, _suffix] -> [{multi_trip_id, trip_id}]
          _ -> []
        end
      end)

    _ =
      if inserts == [] do
        :ok
      else
        true = :ets.delete_all_objects(@table)
        :ets.insert(@table, inserts)

        Logger.info(fn ->
          "#{__MODULE__}: updated with #{length(inserts)} records"
        end)
      end

    {:noreply, [], state, :hibernate}
  end
end
