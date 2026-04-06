defmodule Concentrate.GroupFilter.TimeOutOfRange do
  @moduledoc """
  Rejects StopTimeUpdates which are too far in the future or in the past.
  """
  alias Concentrate.Encoder.TripGroup
  alias Concentrate.StopTimeUpdate
  @behaviour Concentrate.GroupFilter

  # 3 hours
  @max_time_in_future 10_800

  @impl Concentrate.GroupFilter
  def filter(trip_group, now_fn \\ &now/0)

  def filter(%TripGroup{stus: stus} = group, now_fn) do
    now = now_fn.()
    max_time = now + @max_time_in_future

    {stus, _} = Enum.flat_map_reduce(stus, false, &maybe_drop_stu(&1, &2, max_time))
    %{group | stus: stus}
  end

  def filter(%TripGroup{} = other, _now_fn) do
    other
  end

  defp now do
    System.system_time(:second)
  end

  defp maybe_drop_stu(stu, has_valid_time?, max_time)

  defp maybe_drop_stu(stu, true, _) do
    {[stu], true}
  end

  defp maybe_drop_stu(stu, false, max_time) do
    time = StopTimeUpdate.time(stu)

    cond do
      is_nil(time) ->
        {[stu], false}

      time > max_time ->
        {[], false}

      true ->
        {[stu], true}
    end
  end
end
