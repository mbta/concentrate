defmodule Concentrate.TestExAws do
  @moduledoc """
  Implementation of ExAws which sends a message to the calling process.

  This allows us to make assertions about the request without needing AWS
  access in test.
  """
  def request!(message) do
    send(process(), {:ex_aws, message})
  end

  defp process do
    Application.get_env(:concentrate, __MODULE__)[:pid] || self()
  end
end
