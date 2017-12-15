defmodule Concentrate.Parser do
  @moduledoc """
  Behaviour for parsing remote data into lists of vehicles or trip updates.
  """
  alias Concentrate.{VehiclePosition, TripUpdate, StopTimeUpdate}
  @type parsed :: VehiclePosition.t() | TripUpdate.t() | StopTimeUpdate.t()
  @callback parse(binary) :: [parsed]
end
