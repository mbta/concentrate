defmodule Concentrate.Filter.NullStopSequence do
  @moduledoc """
  Filters out StopTimeUpdates with a null `stop_sequence`, since they would not have been merged
  correctly (and wouldn't work with downstream modules that assume a stop sequence is present).
  """
  @behaviour Concentrate.Filter
  alias Concentrate.StopTimeUpdate
  require Logger

  @impl Concentrate.Filter
  def filter(%StopTimeUpdate{} = stu) do
    case StopTimeUpdate.stop_sequence(stu) do
      nil -> :skip
      _ -> {:cont, stu}
    end
  end

  def filter(other), do: {:cont, other}
end
