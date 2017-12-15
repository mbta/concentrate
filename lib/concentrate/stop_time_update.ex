defmodule Concentrate.StopTimeUpdate do
  @moduledoc """
  Structure for representing an update to a StopTime (e.g. a predicted arrival or departure)
  """
  defstruct [
    :trip_id,
    :stop_id,
    :arrival_time,
    :departure_time,
    :stop_sequence,
    :status,
    :track,
    schedule_relationship: :SCHEDULED
  ]

  @opaque t :: %__MODULE__{}

  @doc """
  Return a new StopTimeUpdate with the data from the arguments.
  """
  @spec new(Keyword.t()) :: t
  def new(opts) when is_list(opts) do
    struct!(__MODULE__, opts)
  end
end
