defmodule Concentrate.VehiclePosition.OccupancyStatus do
  @moduledoc """
  Stub struct for ensuring the atoms used for the OccupancyStatus field are explicitly defined.
  """

  import Concentrate.StructHelpers

  # These are used throughout the codebase but are declared explicitly here to ensure that the calls
  # to String.to_existing_atom do not fail:
  defstruct_accessors([
    :EMPTY,
    :MANY_SEATS_AVAILABLE,
    :FEW_SEATS_AVAILABLE,
    :STANDING_ROOM_ONLY,
    :CRUSHED_STANDING_ROOM_ONLY,
    :FULL,
    :NOT_ACCEPTING_PASSENGERS,
    :NO_DATA_AVAILABLE,
    :NOT_BOARDABLE
  ])
end
