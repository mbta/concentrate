defmodule Concentrate.Parser do
  @moduledoc """
  Behaviour for parsing remote data into lists of vehicles or trip updates.
  """
  alias Concentrate.{VehiclePosition, TripUpdate, StopTimeUpdate, Alert}
  @type parsed :: VehiclePosition.t() | TripUpdate.t() | StopTimeUpdate.t() | Alert.t()
  @callback parse(binary) :: [parsed]
end
