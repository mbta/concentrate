defmodule Concentrate.TripUpdate do
  @moduledoc """
  """
  defstruct [
    :trip_id,
    :route_id,
    :direction_id,
    :start_date,
    :start_time,
    schedule_relationship: :SCHEDULED
  ]

  @opaque t :: %__MODULE__{}

  @doc """
  Builds a TripUpdate from keyword arguments.
  """
  def new(opts) when is_list(opts) do
    struct!(__MODULE__, opts)
  end
end
