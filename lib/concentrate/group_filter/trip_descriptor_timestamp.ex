defmodule Concentrate.GroupFilter.TripDescriptorTimestamp do
  @moduledoc """
  Populates timestamp in TripDescriptor with corresponding timestamp in VehiclePosition
  """
  @behaviour Concentrate.GroupFilter
  alias Concentrate.Encoder.TripGroup
  alias Concentrate.{TripDescriptor, VehiclePosition}

  @impl Concentrate.GroupFilter
  def filter(
        %TripGroup{
          td: %TripDescriptor{timestamp: nil} = td,
          vps: [_ | _] = vps
        } = group
      ) do
    timestamp =
      vps
      |> Enum.map(fn x -> VehiclePosition.last_updated(x) end)
      |> Enum.max()

    %{group | td: TripDescriptor.update_timestamp(td, timestamp)}
  end

  def filter(%TripGroup{td: %TripDescriptor{route_id: "Green-" <> _}} = glides_trips) do
    glides_trips
  end

  def filter(%TripGroup{} = other), do: other
end
