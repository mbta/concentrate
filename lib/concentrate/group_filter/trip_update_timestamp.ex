defmodule Concentrate.GroupFilter.TripUpdateTimestamp do
  @moduledoc """
  Populates timestamp in TripUpdate with corresponding timestamp in VehiclePosition
  """
  @behaviour Concentrate.GroupFilter
  alias Concentrate.{TripUpdate, VehiclePosition}

  @impl Concentrate.GroupFilter
  def filter({%TripUpdate{timestamp: nil} = tu, [_ | _] = vps, stus}) do
    timestamp = vps |> Enum.map(fn x -> VehiclePosition.last_updated(x) end) |> Enum.max()

    {TripUpdate.update_timestamp(tu, timestamp), vps, stus}
  end

  def filter(other), do: other
end
