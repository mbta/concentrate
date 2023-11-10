defmodule TransitRealtime.PbExtension do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.12.0"

  extend(TransitRealtime.VehicleDescriptor, :consist, 1001,
    repeated: true,
    type: TransitRealtime.Consist
  )

  extend(TransitRealtime.TripUpdate.StopTimeUpdate, :boarding_status, 1001,
    optional: true,
    type: :string
  )

  extend(TransitRealtime.TripUpdate.StopTimeUpdate, :platform_id, 1002,
    optional: true,
    type: :string
  )

  extend(TransitRealtime.TripDescriptor, :route_pattern_id, 1001, optional: true, type: :string)
end
