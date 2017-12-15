defmodule Concentrate.VehiclePosition do
  @moduledoc """
  Structure for representing a transit vehicle's position.
  """
  defstruct [
    :id,
    :trip_id,
    :stop_id,
    :label,
    :license_plate,
    :latitude,
    :longitude,
    :bearing,
    :speed,
    :odometer,
    :status,
    :stop_sequence,
    :last_updated
  ]

  @opaque t :: %__MODULE__{}

  @doc """
  Return a new VehiclePosition with the data from the arguments.
  """
  @spec new(Keyword.t()) :: t
  def new(opts) when is_list(opts) do
    struct!(__MODULE__, opts)
  end
end
