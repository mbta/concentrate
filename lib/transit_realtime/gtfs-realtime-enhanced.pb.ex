defmodule TransitRealtime.Consist do
  @moduledoc false

  use Protobuf, syntax: :proto2, protoc_gen_elixir_version: "0.12.0"

  field :label, 1, required: true, type: :string
end