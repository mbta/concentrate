defmodule Concentrate.GTFS.Routes do
  @moduledoc """
  Server which maintains a list of route_id -> route_type mappings.
  """
  use GenStage
  require Logger
  import :binary, only: [copy: 1]
  @table __MODULE__

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def route_type(route_id) do
    hd(:ets.lookup_element(@table, route_id, 2))
  rescue
    ArgumentError -> nil
  end

  def init(opts) do
    @table = :ets.new(@table, [:named_table, :public, :duplicate_bag])
    {:consumer, %{}, opts}
  end

  def handle_events(events, _from, state) do
    inserts =
      for event <- events,
          {"routes.txt", route_body} <- event,
          lines = String.split(route_body, "\n"),
          {:ok, row} <- CSV.decode(lines, headers: true) do
        {copy(row["route_id"]), String.to_integer(row["route_type"])}
      end

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
