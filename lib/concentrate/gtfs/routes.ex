defmodule Concentrate.GTFS.Routes do
  use GenStage
  require Logger
  import :binary, only: [copy: 1]

  @table __MODULE__

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def route_type(route_id) do
    :ets.lookup_element(@table, route_id, 2)
  rescue
    ArgumentError -> nil
  end

  @impl GenStage
  def init(opts) do
    @table = :ets.new(@table, [:named_table, :public, :set])
    {:consumer, [], opts}
  end

  @impl GenStage
  def handle_events(events, _from, state) do
    inserts =
      for event <- events,
          {"routes.txt", trip_body} <- event,
          lines = String.split(trip_body, "\n"),
          {:ok, row} <- CSV.decode(lines, headers: true) do
        {copy(row["route_id"]), String.to_integer(row["route_type"])}
      end

    if inserts != [] do
      true = :ets.delete_all_objects(@table)
      :ets.insert(@table, inserts)

      Logger.info(fn ->
        "#{__MODULE__}: updated with #{length(inserts)} records"
      end)
    end

    {:noreply, [], state, :hibernate}
  end
end
