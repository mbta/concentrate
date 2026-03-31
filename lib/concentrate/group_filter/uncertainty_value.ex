defmodule Concentrate.GroupFilter.UncertaintyValue do
  @moduledoc """
  Populates uncertainty in TripDescriptor based on the update_type value
  """
  @behaviour Concentrate.GroupFilter
  alias Concentrate.Encoder.TripGroup
  alias Concentrate.{StopTimeUpdate, TripDescriptor}

  @impl Concentrate.GroupFilter
  def filter(
        %TripGroup{
          td: %TripDescriptor{update_type: update_type},
          stus: stus
        } = group
      )
      when not is_nil(update_type) do
    stus =
      update_type
      |> calculate_uncertainty()
      |> set_uncertainty(stus)

    %{group | stus: stus}
  end

  def filter(%TripGroup{} = other), do: other

  defp set_uncertainty(nil, stus), do: stus

  defp set_uncertainty(uncertainty, stus) do
    Enum.map(stus, fn stu ->
      StopTimeUpdate.update_uncertainty(stu, uncertainty)
    end)
  end

  defp calculate_uncertainty("mid_trip"), do: 60
  defp calculate_uncertainty("at_terminal"), do: 120
  defp calculate_uncertainty("reverse_trip"), do: 360
  defp calculate_uncertainty(_), do: nil
end
