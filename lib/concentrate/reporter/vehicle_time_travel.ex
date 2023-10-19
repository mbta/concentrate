defmodule Concentrate.Reporter.VehicleTimeTravel do
  @moduledoc """
  Reports vehicles where the timestamp goes back in time.
  """
  require Logger
  alias Concentrate.VehiclePosition

  @behaviour Concentrate.Reporter

  @impl Concentrate.Reporter
  def init do
    %{}
  end

  @impl Concentrate.Reporter
  def log(groups, vehicle_timestamps) do
    vehicle_timestamps = Enum.reduce(groups, vehicle_timestamps, &log_group/2)
    {[], vehicle_timestamps}
  end

  defp log_group({_td, vps, _stus}, acc) do
    Enum.reduce(vps, acc, &log_vehicle/2)
  end

  defp log_vehicle(vp, acc) do
    vehicle_id = VehiclePosition.id(vp)
    timestamp = VehiclePosition.last_updated(vp)
    old_timestamp = Map.get(acc, vehicle_id)

    if timestamp && old_timestamp && old_timestamp > timestamp do
      trip_id = VehiclePosition.trip_id(vp)

      Logger.warning(
        "event=vehicle_time_travel vehicle_id=#{vehicle_id} trip_id=#{trip_id} later=#{old_timestamp} earlier=#{timestamp}"
      )
    end

    if timestamp do
      Map.put(acc, vehicle_id, timestamp)
    else
      acc
    end
  end
end
