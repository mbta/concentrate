defmodule Concentrate.Reporter.VehicleLatency do
  @moduledoc """
  Reporter which logs how recently the latest vehicle was updated.
  """
  @behaviour Concentrate.Reporter
  alias Concentrate.GTFS.Routes
  alias Concentrate.VehiclePosition
  alias Concentrate.TripDescriptor
  require Logger

  @impl Concentrate.Reporter
  def init do
    []
  end

  @impl Concentrate.Reporter
  def log(groups, state) do
    {latest, average, median, count} = lateness(groups)

    route_type_lateness =
      groups
      |> Stream.filter(&(elem(&1, 0) != nil))
      |> Enum.group_by(&(&1 |> elem(0) |> TripDescriptor.route_id() |> Routes.route_type()))
      |> Stream.filter(&(elem(&1, 0) != nil))
      |> Enum.flat_map(&lateness_for_type/1)

    groups
    # get the vehicle positions
    |> Enum.flat_map(&elem(&1, 1))
    |> Enum.each(
      &Logger.info([
        "event=processed_vehicle id=",
        inspect(VehiclePosition.id(&1)),
        ",latitude=",
        inspect(VehiclePosition.latitude(&1)),
        ",longitude=",
        inspect(VehiclePosition.longitude(&1))
      ])
    )

    {[
       latest_vehicle_lateness: latest,
       average_vehicle_lateness: average,
       median_vehicle_lateness: median,
       vehicle_count: count
     ] ++
       route_type_lateness, state}
  end

  defp lateness_for_type({type, groups}) do
    latest_label = String.to_atom("latest_#{type}_lateness")
    average_label = String.to_atom("average_#{type}_lateness")
    median_label = String.to_atom("median_#{type}_lateness")
    count_label = String.to_atom("#{type}_count")

    {latest, average, median, count} = lateness(groups)

    [
      {latest_label, latest},
      {average_label, average},
      {median_label, median},
      {count_label, count}
    ]
  end

  defp lateness(groups) do
    now = utc_now()

    latenesses =
      groups
      # get the vehicle positions
      |> Enum.flat_map(&elem(&1, 1))
      |> Enum.flat_map(&timestamp(&1, now))

    latest =
      if latenesses == [] do
        :undefined
      else
        Enum.min(latenesses)
      end

    {average, count} = average(latenesses)
    median = Statistics.median(latenesses)
    {latest, average, median, count}
  end

  defp timestamp(%VehiclePosition{} = vp, now) do
    case VehiclePosition.last_updated(vp) do
      nil -> []
      timestamp -> [now - timestamp]
    end
  end

  defp timestamp(_, _) do
    []
  end

  def average([]) do
    {:undefined, 0}
  end

  def average(items) do
    {total, count} =
      Enum.reduce(items, {0, 0}, fn v, {total, count} -> {total + v, count + 1} end)

    {total / count, count}
  end

  defp utc_now do
    :os.system_time(:seconds)
  end
end
