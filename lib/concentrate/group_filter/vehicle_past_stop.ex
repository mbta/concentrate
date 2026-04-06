defmodule Concentrate.GroupFilter.VehiclePastStop do
  @moduledoc """
  Removes stop times if there's a vehicle on the trip that's already left the stop.
  """
  @behaviour Concentrate.GroupFilter
  alias Concentrate.Encoder.TripGroup
  alias Concentrate.{StopTimeUpdate, TripDescriptor, VehiclePosition}

  @impl Concentrate.GroupFilter
  def filter(%TripGroup{td: %TripDescriptor{}, vps: [vp], stus: stus} = group) do
    stop_sequence = VehiclePosition.stop_sequence(vp)

    stus =
      if is_integer(stop_sequence) do
        Enum.drop_while(stus, &(StopTimeUpdate.stop_sequence(&1) < stop_sequence))
      else
        stus
      end

    %{group | stus: stus}
  end

  def filter(%TripGroup{} = other), do: other
end
