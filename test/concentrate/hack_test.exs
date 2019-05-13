defmodule Concentrate.HackTest do
  @moduledoc false
  use ExUnit.Case, async: true

  test "print environment" do
    IO.inspect(System.get_env())
  end
end
