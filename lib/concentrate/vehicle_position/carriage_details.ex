defmodule Concentrate.VehiclePosition.CarriageDetails do
  import Concentrate.StructHelpers

  @moduledoc """
  Structure for representing a Carriage Detail inside of multi_carriage_details
  """
  @derive Jason.Encoder
  defstruct_accessors([
    :id,
    :label,
    :carriage_sequence,
    :occupancy_status,
    :occupancy_percentage
  ])

  def build_multi_carriage_details_struct(nil) do
    nil
  end

  # Ensures that the nil / empty values are appropriate as per PB spec:
  def build_multi_carriage_details_struct(multi_carriage_details) do
    Enum.map(multi_carriage_details, fn carriage_details ->
      %{
        id: id,
        label: label,
        carriage_sequence: carriage_sequence,
        occupancy_status: occupancy_status,
        occupancy_percentage: occupancy_percentage
      } = get_atomized_carriage_details(carriage_details)

      # Assign safe default values to the expected struct so the values don't get swallowed:
      %Concentrate.VehiclePosition.CarriageDetails{
        id: if(id == nil, do: "", else: id),
        label: if(label == nil, do: "", else: label),
        carriage_sequence: if(carriage_sequence == nil, do: 1, else: carriage_sequence),
        occupancy_status:
          if(occupancy_status == nil,
            do: :NO_DATA_AVAILABLE,
            else: occupancy_status
          ),
        occupancy_percentage: if(occupancy_percentage == nil, do: -1, else: occupancy_percentage)
      }
    end)
  end

  # Convert to atomized keys, so that both atoms and string keys are supported:
  defp get_atomized_carriage_details(carriage_details) do
    atomized_carriage_details =
      for {key, val} <- carriage_details,
          into: %{},
          do: {if(is_atom(key), do: key, else: String.to_atom(key)), val}

    unatomized_occupancy_status =
      if Map.has_key?(atomized_carriage_details, :occupancy_status),
        do: atomized_carriage_details.occupancy_status,
        else: nil

    %{
      id:
        if(Map.has_key?(atomized_carriage_details, :id),
          do: atomized_carriage_details.id,
          else: nil
        ),
      label:
        if(Map.has_key?(atomized_carriage_details, :label),
          do: atomized_carriage_details.label,
          else: nil
        ),
      carriage_sequence:
        if(Map.has_key?(atomized_carriage_details, :carriage_sequence),
          do: atomized_carriage_details.carriage_sequence,
          else: nil
        ),
      occupancy_status:
        if(is_atom(unatomized_occupancy_status),
          do: unatomized_occupancy_status,
          else: String.to_atom(unatomized_occupancy_status)
        ),
      occupancy_percentage:
        if(Map.has_key?(atomized_carriage_details, :occupancy_percentage),
          do: atomized_carriage_details.occupancy_percentage,
          else: nil
        )
    }
  end
end
