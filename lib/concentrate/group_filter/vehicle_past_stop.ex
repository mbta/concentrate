defmodule Concentrate.GroupFilter.VehiclePastStop do
  @moduledoc """
  Removes stop times if there's a vehicle on the trip that's already left the stop.
  """
  @behaviour Concentrate.GroupFilter
  alias Concentrate.{StopTimeUpdate, TripDescriptor, VehiclePosition}

  @impl Concentrate.GroupFilter
  def filter({%TripDescriptor{} = td, [vp], stus}) do
    stop_sequence = VehiclePosition.stop_sequence(vp)

    stus =
      if is_integer(stop_sequence) do
        Enum.drop_while(stus, &(StopTimeUpdate.stop_sequence(&1) < stop_sequence))
      else
        stus
      end

    {td, [vp], stus}
  end

  def filter(other), do: other
end
