defmodule Concentrate.VehiclePosition.CarriageDetails do
  @moduledoc """
  Provides a few helper functions for cleaning up the multi_carriage_details field, mostly
  for Protobuf encoding compatibility (atoms as keys, no nil values).
  """

  import Concentrate.Encoder.GTFSRealtimeHelpers

  def build_multi_carriage_details(nil) do
    nil
  end

  # Ensures that the nil / empty values are appropriate as per PB spec:
  def build_multi_carriage_details(multi_carriage_details) do
    Enum.map(multi_carriage_details, fn carriage_details ->
      carriage_details
      |> get_atomized_carriage_details()
      |> drop_nil_values()
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
