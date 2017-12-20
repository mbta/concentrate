defmodule Concentrate.VehiclePosition do
  @moduledoc """
  Structure for representing a transit vehicle's position.
  """
  import Concentrate.StructHelpers

  defstruct_accessors([
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
  ])

  @opaque t :: %__MODULE__{}

  def new(opts) do
    # required fields
    _ = Keyword.fetch!(opts, :latitude)
    _ = Keyword.fetch!(opts, :longitude)
    super(opts)
  end

  defimpl Concentrate.Mergeable do
    def key(%{id: id}), do: id

    @doc """
    Merging VehiclePositions takes the latest position for a given vehicle.
    """
    def merge(first, second) do
      positions = [first, second]
      Enum.min_by(positions, &DateTime.to_unix(&1.last_updated))
    end
  end
end
