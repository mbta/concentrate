defmodule Concentrate.Filter.RoundSpeedAndBearing do
  @moduledoc """
  Rounds the speed and bearing. The speed is rounded to a float with precision
  of 1 decimal place, and set to nil if < 1 m/s. The bearing is truncated.
  """
  @behaviour Concentrate.Filter
  alias Concentrate.VehiclePosition

  @impl Concentrate.Filter
  def filter(%VehiclePosition{} = vp) do
    speed =
      case VehiclePosition.speed(vp) do
        nil -> nil
        small when small < 1 -> nil
        other -> Float.round(other, 1)
      end

    bearing =
      if bearing = VehiclePosition.bearing(vp) do
        trunc(bearing)
      else
        nil
      end

    {:cont, VehiclePosition.update(vp, %{speed: speed, bearing: bearing})}
  end

  def filter(other) do
    {:cont, other}
  end
end
