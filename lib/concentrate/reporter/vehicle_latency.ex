defmodule Concentrate.Reporter.VehicleLatency do
  @moduledoc """
  Reporter which logs how recently the latest vehicle was updated.
  """
  @behaviour Concentrate.Reporter
  alias Concentrate.VehiclePosition

  @impl Concentrate.Reporter
  def init do
    []
  end

  @impl Concentrate.Reporter
  def log(parsed, state) do
    latest_vehicle_timestamp = Enum.reduce(parsed, nil, &timestamp/2)

    lateness =
      if latest_vehicle_timestamp do
        utc_now() - latest_vehicle_timestamp
      else
        :undefined
      end

    {[latest_vehicle_lateness: lateness], state}
  end

  defp timestamp(%VehiclePosition{} = vp, latest_timestamp) do
    last_updated = VehiclePosition.last_updated(vp)

    if latest_timestamp do
      max(latest_timestamp, last_updated)
    else
      last_updated
    end
  end

  defp timestamp(_, latest_timestamp) do
    latest_timestamp
  end

  defp utc_now do
    :os.system_time(:seconds)
  end
end
