defmodule Concentrate.Encoder.TripGroup do
  @moduledoc """
  Struct for information about a single trip. Callers are responsible for
  ensuring that all fields are related to the same trip ID.
  """

  defstruct td: nil,
            vps: [],
            stus: [],
            tp: nil

  @type t :: %__MODULE__{
          td: Concentrate.TripDescriptor.t() | nil,
          vps: [Concentrate.VehiclePosition.t()],
          stus: [Concentrate.StopTimeUpdate.t()],
          tp: Concentrate.TripProperties.t() | nil
        }
end
