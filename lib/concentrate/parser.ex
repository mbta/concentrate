defmodule Concentrate.Parser do
  @moduledoc """
  Behaviour for parsing remote data.

  Generally, these return a list of VehiclePosition, TripDescriptor, or
  StopTimeUpdate data, but other data can be returned as well.

  """
  alias Concentrate.{StopTimeUpdate, TripDescriptor, VehiclePosition}
  @type parsed :: VehiclePosition.t() | TripDescriptor.t() | StopTimeUpdate.t()
  @callback parse(binary, Keyword.t()) :: [term]
end
