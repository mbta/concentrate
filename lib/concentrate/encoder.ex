defmodule Concentrate.Encoder do
  @moduledoc """
  Encoders define a single callback:

  encode/1: given a list of parsed data, returns a binary
  """
  @callback encode([Concentrate.Parser.parsed()]) :: binary
end
