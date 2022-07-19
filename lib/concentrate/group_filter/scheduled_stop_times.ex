defmodule Concentrate.GroupFilter.ScheduledStopTimes do
  @moduledoc """
  Uses the static GTFS schedule to fill in missing arrival/departure times on stop time updates
  that have specific `status` values.

  The desired status values must be set in app configuration at compile time. For example:

      config :concentrate,
        group_filters: [
          {
            Concentrate.GroupFilter.ScheduledStopTimes,
            on_time_statuses: ["status 1", "status 2", "status 3"]
          }
        ]

  If no status values are configured, enabling this filter has no effect.
  """
  @behaviour Concentrate.GroupFilter
  alias Concentrate.{StopTimeUpdate, TripDescriptor}, warn: false

  @impl Concentrate.GroupFilter
  def filter(trip_group, gtfs_stop_times \\ Concentrate.GTFS.StopTimes)

  config_path = [:group_filters, __MODULE__, :on_time_statuses]
  @on_time_statuses Application.compile_env(:concentrate, config_path, [])

  if @on_time_statuses == [] do
    def filter(trip_group, _), do: trip_group
  else
    def filter({trip_descriptor, vehicle_positions, [_ | _] = stop_time_updates}, gtfs_stop_times)
        when not is_nil(trip_descriptor) do
      {
        trip_descriptor,
        vehicle_positions,
        filter_stop_time_updates(
          stop_time_updates,
          TripDescriptor.start_date(trip_descriptor),
          gtfs_stop_times
        )
      }
    end

    def filter(trip_group, _), do: trip_group

    defp filter_stop_time_updates(stop_time_updates, nil, _), do: stop_time_updates

    defp filter_stop_time_updates(stop_time_updates, trip_date, gtfs_stop_times) do
      Enum.map(stop_time_updates, fn stop_time_update ->
        fill_in_arrival_departure(
          stop_time_update,
          trip_date,
          StopTimeUpdate.arrival_time(stop_time_update),
          StopTimeUpdate.departure_time(stop_time_update),
          StopTimeUpdate.status(stop_time_update),
          gtfs_stop_times
        )
      end)
    end

    defp fill_in_arrival_departure(stop_time_update, trip_date, nil, nil, status, gtfs_stop_times)
         when status in @on_time_statuses do
      trip_id = StopTimeUpdate.trip_id(stop_time_update)
      stop_sequence = StopTimeUpdate.stop_sequence(stop_time_update)

      case gtfs_stop_times.arrival_departure(trip_id, stop_sequence, trip_date) do
        {arrival_time, departure_time} ->
          stop_time_update
          |> StopTimeUpdate.update_arrival_time(arrival_time)
          |> StopTimeUpdate.update_departure_time(departure_time)

        :unknown ->
          stop_time_update
      end
    end

    defp fill_in_arrival_departure(stop_time_update, _, _, _, _, _), do: stop_time_update
  end
end
