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
          do:
            {if(is_atom(key), do: key, else: String.to_atom(key)),
             if(key in ["occupancy_status", :occupancy_status] and not is_atom(val),
               do: String.to_atom(val),
               else: val
             )}

    Map.take(
      atomized_carriage_details,
      ~w(id label carriage_sequence occupancy_status occupancy_percentage)a
    )
  end
end
