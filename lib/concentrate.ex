defmodule Concentrate do
  @moduledoc """
  Application entry point for Concentrate
  """
  use Application

  def start(_type, _args) do
    Concentrate.Supervisor.start_link()
  end
end
