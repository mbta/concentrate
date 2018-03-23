defmodule Concentrate.GroupFilter.Cache.VehicleBeforeStop do
  @moduledoc """
  Server to maintain a cache of previously seen StopTimeUpdates for a given trip.

  As the vehicle moves through, we'll remove the older updates. Periodically,
  we'll scan for StopTimeUpdates in the past and remove them.
  """
  use GenServer
  alias Concentrate.{VehiclePosition, StopTimeUpdate}

  @table __MODULE__
  # 5 minutes
  @stale_timeout_seconds 300

  @spec stop_time_updates_for_vehicle(VehiclePosition.t(), [StopTimeUpdate.t()]) :: [
          StopTimeUpdate.t()
        ]
  def stop_time_updates_for_vehicle(vehicle_position, stop_time_updates) do
    if is_integer(VehiclePosition.stop_sequence(vehicle_position)) do
      insert_new_updates!(stop_time_updates)
      delete_old_updates(vehicle_position)
      fetch_updates_with_stop_sequence_ge_than_vehicle(vehicle_position)
    else
      stop_time_updates
    end
  rescue
    ArgumentError ->
      stop_time_updates
  end

  defp insert_new_updates!(stop_time_updates) do
    inserts =
      for stu <- stop_time_updates,
          stop_sequence <- List.wrap(StopTimeUpdate.stop_sequence(stu)) do
        trip_id = StopTimeUpdate.trip_id(stu)
        time = StopTimeUpdate.time(stu)
        :ets.match_delete(@table, {trip_id, stop_sequence, :_, :_})
        {trip_id, stop_sequence, time, stu}
      end

    :ets.insert(@table, inserts)
  end

  defp fetch_updates_with_stop_sequence_ge_than_vehicle(vp) do
    unsorted =
      :ets.select(@table, [
        {
          {VehiclePosition.trip_id(vp), :"$1", :_, :"$2"},
          [{:>=, :"$1", VehiclePosition.stop_sequence(vp)}],
          [:"$2"]
        }
      ])

    Enum.sort_by(unsorted, &StopTimeUpdate.stop_sequence/1)
  end

  defp delete_old_updates(vp) do
    :ets.select_delete(@table, [
      {
        {VehiclePosition.trip_id(vp), :"$1", :_, :_},
        [{:<, :"$1", VehiclePosition.stop_sequence(vp)}],
        [true]
      }
    ])
  end

  def start_link([]) do
    GenServer.start_link(__MODULE__, [])
  end

  @impl GenServer
  def init([]) do
    @table = :ets.new(@table, [:bag, :named_table, :public])
    schedule_clear!()
    {:ok, []}
  end

  @impl GenServer
  def handle_info(:clear, state) do
    now = System.system_time(:seconds)
    minimum_time = now - @stale_timeout_seconds

    :ets.select_delete(@table, [
      {
        {:_, :_, :"$1", :_},
        [{:<, :"$1", minimum_time}],
        [true]
      }
    ])

    {:noreply, state}
  end

  def handle_info(message, state) do
    super(message, state)
  end

  defp schedule_clear! do
    send(self(), :clear)
  end
end
