defmodule Concentrate.Encoder do
  @moduledoc """
  Encoders define a single callback:

  encode/1: given a list of parsed data, returns a binary
  encode_groups/1: given a pre-grouped list of data, returns as binary
  """
  @callback encode([Concentrate.Parser.parsed()]) :: binary
  @callback encode_groups([Concentrate.Encoder.GTFSRealtimeHelpers.trip_group()]) :: binary

  @optional_callbacks encode_groups: 1
end
