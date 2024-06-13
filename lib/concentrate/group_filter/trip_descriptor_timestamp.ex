defmodule Concentrate.GroupFilter.TripDescriptorTimestamp do
  @moduledoc """
  Populates timestamp in TripDescriptor with corresponding timestamp in VehiclePosition
  """
  @behaviour Concentrate.GroupFilter
  alias Concentrate.{TripDescriptor, VehiclePosition}

  @impl Concentrate.GroupFilter
  def filter({%TripDescriptor{timestamp: nil} = td, [_ | _] = vps, stus}) do
    timestamp = vps |> Enum.map(fn x -> VehiclePosition.last_updated(x) end) |> Enum.max()

    {TripDescriptor.update_timestamp(td, timestamp), vps, stus}
  end

  def filter({%TripDescriptor{route_id: "Green-" <> _}, _, _} = glides_trips) do
    glides_trips
  end

  def filter(other), do: other
end
