defmodule Concentrate.Parser do
  @moduledoc """
  Behaviour for parsing remote data.

  Returns an enumerable.
  """
  @callback parse(binary, Keyword.t()) :: Enumerable.t()
end
