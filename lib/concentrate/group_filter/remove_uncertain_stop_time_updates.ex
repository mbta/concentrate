defmodule Concentrate.GroupFilter.RemoveUncertainStopTimeUpdates do
  @moduledoc """
  The excluded uncertainty values for each route must be set in app configuration
  at compile time. For example:

      config :concentrate,
        group_filters: [
          {
            Concentrate.GroupFilter.RemoveUncertainStopTimeUpdates,
            uncertainties_by_route: ["status 1", "status 2", "status 3"]
          }
        ]

  If no uncertainty values are configured, enabling this filter has no effect.
  """
  alias Concentrate.{StopTimeUpdate, TripDescriptor}

  @behaviour Concentrate.GroupFilter

  @type route_id() :: String.t()
  # uncertainty => direction_id(s) in which that uncertainty should be suppressed
  @type uncertainties() :: [%{integer() => [integer()]}]
  @type uncertainties_by_route() :: %{
          route_id() => uncertainties()
        }

  config_path = [:group_filters, __MODULE__, :uncertainties_by_route]
  @uncertainties_by_route Application.compile_env(:concentrate, config_path, %{})

  @impl Concentrate.GroupFilter
  def filter(trip_descriptor, exclusions \\ @uncertainties_by_route)

  def filter(group, exclusions) when exclusions == %{}, do: group

  def filter({nil, _, _} = group, _), do: group

  def filter({trip_descriptor, vehicle_positions, stop_time_updates}, exclusions) do
    route_id = TripDescriptor.route_id(trip_descriptor)
    direction_id = TripDescriptor.direction_id(trip_descriptor)
    route_exclusions = Map.get(exclusions, route_id, nil)

    {trip_descriptor, vehicle_positions,
     exclude(stop_time_updates, route_exclusions, direction_id)}
  end

  @spec exclude([StopTimeUpdate.t()], uncertainties() | nil, 0 | 1) :: [StopTimeUpdate.t()]
  defp exclude(updates, nil, _direction_id), do: updates

  defp exclude(updates, uncertainties, direction_id) do
    Enum.reject(updates, fn stop_time_update ->
      case Map.get(uncertainties, StopTimeUpdate.uncertainty(stop_time_update)) do
        nil ->
          false

        direction_ids ->
          direction_id in direction_ids
      end
    end)
  end
end
