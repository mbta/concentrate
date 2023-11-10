defmodule TransitRealtime.PbExtension do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.12.0"

  extend(TransitRealtime.VehicleDescriptor, :consist, 1001,
    repeated: true,
    type: TransitRealtime.Consist
  )
end
