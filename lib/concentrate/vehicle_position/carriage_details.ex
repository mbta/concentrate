defmodule Concentrate.VehiclePosition.CarriageDetails do
  @moduledoc """
  Provides a few helper functions for cleaning up the multi_carriage_details field, mostly
  for Protobuf encoding compatibility (atoms as keys, no nil values).
  """

  alias Concentrate.VehiclePosition.OccupancyStatus
  import Concentrate.StructHelpers
  import Concentrate.Encoder.GTFSRealtimeHelpers

  # These are used throughout the codebase but are declared explicitly here to ensure that the calls
  # to String.to_existing_atom do not fail:
  defstruct_accessors([
    :occupancy_status,
    :occupancy_percentage,
    :carriage_sequence,
    :label,
    :id,
    :orientation
  ])

  def build_multi_carriage_details(multi_carriage_details, feed_type \\ :normal)

  def build_multi_carriage_details(nil, _) do
    nil
  end

  # Ensures that the nil / empty values are appropriate as per PB spec:
  def build_multi_carriage_details(multi_carriage_details, feed_type) do
    Enum.map(multi_carriage_details, fn carriage_details ->
      carriage_details
      |> get_atomized_carriage_details(feed_type)
      |> drop_nil_values()
    end)
  end

  # Convert to atomized keys, so that both atoms and string keys are supported:
  defp get_atomized_carriage_details(carriage_details, :enhanced) do
    atomized_carriage_details =
      for pair <- carriage_details, into: %{}, do: atomize_key_value_pair(pair)

    Map.take(
      atomized_carriage_details,
      ~w(id label carriage_sequence occupancy_status occupancy_percentage orientation)a
    )
  end

  defp get_atomized_carriage_details(carriage_details, _) do
    atomized_carriage_details =
      for pair <- carriage_details, into: %{}, do: atomize_key_value_pair(pair)

    Map.take(
      atomized_carriage_details,
      ~w(id label carriage_sequence occupancy_status occupancy_percentage)a
    )
  end

  defp atomize_key_value_pair({key, value}) when key in ["occupancy_status", :occupancy_status] do
    {atomize_key(key), OccupancyStatus.parse_to_atom(value)}
  end

  defp atomize_key_value_pair({key, value}) when key in ["orientation", :orientation] do
    {atomize_key(key), parse_orientation(value)}
  end

  defp atomize_key_value_pair({key, value}) do
    {atomize_key(key), value}
  end

  defp atomize_key(key) when not is_atom(key) do
    String.to_existing_atom(key)
  end

  defp atomize_key(key), do: key

  defp parse_orientation("AB"), do: :AB
  defp parse_orientation("BA"), do: :BA
  defp parse_orientation(val), do: val
end
