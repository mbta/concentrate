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
    :stop_sequence,
    :last_updated,
    :consist,
    :occupancy_status,
    :occupancy_percentage,
    :multi_carriage_details,
    status: :IN_TRANSIT_TO
  ])

  defmodule Consist do
    @moduledoc """
    The consist is the set of individual cars which make up the vehicle we're tracking.

    For example, a subway train can have 6 cars, each of which would have a separate item in the consist.
    """
    defstruct_accessors([
      :label
    ])
  end

  def new(opts) do
    # required fields
    _ = Keyword.fetch!(opts, :latitude)
    _ = Keyword.fetch!(opts, :longitude)
    super(opts)
  end

  def last_updated_truncated(%__MODULE__{last_updated: number}) when is_integer(number) do
    number
  end

  def last_updated_truncated(%__MODULE__{last_updated: number}) when is_float(number) do
    trunc(number)
  end

  def last_updated_truncated(%__MODULE__{last_updated: nil}) do
    nil
  end

  defimpl Concentrate.Mergeable do
    def key(%{id: id}), do: id

    @doc """
    Merging VehiclePositions takes the latest position for a given vehicle.
    """
    def merge(first, %{last_updated: nil}) do
      first
    end

    def merge(%{last_updated: nil}, second) do
      second
    end

    def merge(first, second) do
      if first.last_updated <= second.last_updated do
        do_merge(first, second)
      else
        do_merge(second, first)
      end
    end

    defp do_merge(first, second) do
      %{
        second
        | trip_id: first_value(second.trip_id, first.trip_id),
          stop_id: first_value(second.stop_id, first.stop_id),
          label: first_value(second.label, first.label),
          license_plate: first_value(second.license_plate, first.license_plate),
          latitude: first_value(second.latitude, first.latitude),
          longitude: first_value(second.longitude, first.longitude),
          bearing: first_value(second.bearing, first.bearing),
          speed: first_value(second.speed, first.speed),
          odometer: first_value(second.odometer, first.odometer),
          stop_sequence: first_value(second.stop_sequence, first.stop_sequence),
          occupancy_status: first_value(second.occupancy_status, first.occupancy_status),
          occupancy_percentage:
            first_value(second.occupancy_percentage, first.occupancy_percentage),
          multi_carriage_details:
            first_value(second.multi_carriage_details, first.multi_carriage_details),
          consist: first_list_value(second.consist, first.consist)
      }
    end

    defp first_value(value, _) when not is_nil(value), do: value
    defp first_value(_, value), do: value

    defp first_list_value([_ | _] = value, _), do: value
    defp first_list_value([], value), do: value
    defp first_list_value(value1, value2), do: first_value(value1, value2)
  end
end
