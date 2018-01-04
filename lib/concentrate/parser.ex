defmodule Concentrate.Parser do
  @moduledoc """
  Behaviour for parsing remote data.

  Generally, these return a list of VehiclePosition, TripUpdate, or
  StopTimeUpdate data, but other data can be returned as well.

  """
  alias Concentrate.{VehiclePosition, TripUpdate, StopTimeUpdate}
  @type parsed :: VehiclePosition.t() | TripUpdate.t() | StopTimeUpdate.t()
  @callback parse(binary, Keyword.t()) :: [term]
end
