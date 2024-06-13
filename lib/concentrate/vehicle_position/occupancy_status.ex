defmodule Concentrate.VehiclePosition.OccupancyStatus do
  @moduledoc """
  Stub for ensuring the atoms used for the OccupancyStatus field are explicitly defined.
  """

  # These are used throughout the codebase but are declared explicitly here to ensure that the calls
  # to String.to_existing_atom do not fail:
  def valid_occupancy_status?(occupancy_status) do
    Enum.member?(
      [
        :EMPTY,
        :MANY_SEATS_AVAILABLE,
        :FEW_SEATS_AVAILABLE,
        :STANDING_ROOM_ONLY,
        :CRUSHED_STANDING_ROOM_ONLY,
        :FULL,
        :NOT_ACCEPTING_PASSENGERS,
        :NO_DATA_AVAILABLE,
        :NOT_BOARDABLE
      ],
      occupancy_status
    )
  end

  def parse_to_atom(occupancy_status) when is_atom(occupancy_status), do: occupancy_status

  def parse_to_atom(occupancy_status) do
    atom_occ_status = String.to_existing_atom(occupancy_status)
    if valid_occupancy_status?(atom_occ_status), do: atom_occ_status, else: :NO_DATA_AVAILABLE
  end
end
