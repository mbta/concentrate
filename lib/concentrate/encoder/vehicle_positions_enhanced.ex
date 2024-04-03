defmodule Concentrate.Encoder.VehiclePositionsEnhanced do
  @moduledoc """
  Encodes a list of parsed data into a VehiclePositions_enhanced.json file.
  """
  @behaviour Concentrate.Encoder
  alias Concentrate.{TripDescriptor, VehiclePosition}
  alias VehiclePosition.Consist, as: VehiclePositionConsist
  import Concentrate.Encoder.GTFSRealtimeHelpers
  import Concentrate.Encoder.VehiclePositions, only: [entity_id: 1, trip_descriptor: 1]

  @impl Concentrate.Encoder
  def encode_groups(groups, opts \\ []) when is_list(groups) do
    message = %{
      "header" => feed_header(opts),
      "entity" => Enum.flat_map(groups, fn group -> build_entity(group, &enhanced_data/1) end)
    }

    Jason.encode!(message)
  end

  defp enhanced_data(update) do
    %{
      last_trip: TripDescriptor.last_trip(update)
    }
  end

  def build_entity(_, enhanced_data \\ fn _ -> %{} end)

  def build_entity({%TripDescriptor{} = td, vps, _stus}, enhanced_data_fn) do
    trip =
      td
      |> trip_descriptor()
      |> Map.put("revenue", TripDescriptor.revenue(td))
      |> Map.merge(enhanced_data_fn.(td))
      |> drop_nil_values()

    for vp <- vps do
      %{
        "id" => entity_id(vp),
        "vehicle" => build_vehicle(vp, trip)
      }
    end
  end

  def build_entity({nil, vps, _stus}, _enhanced_data_fn) do
    # vehicles without a trip
    for vp <- vps,
        trip_id = VehiclePosition.trip_id(vp),
        not is_nil(trip_id) do
      trip = %{
        "trip_id" => trip_id,
        "schedule_relationship" => "UNSCHEDULED"
      }

      %{
        "id" => entity_id(vp),
        "vehicle" => build_vehicle(vp, trip)
      }
    end
  end

  defp build_vehicle(%VehiclePosition{} = vp, trip) do
    descriptor =
      drop_nil_values(%{
        "id" => VehiclePosition.id(vp),
        "label" => VehiclePosition.label(vp),
        "license_plate" => VehiclePosition.license_plate(vp),
        "consist" => optional_map(VehiclePosition.consist(vp), &build_consist/1)
      })

    position =
      drop_nil_values(%{
        "latitude" => VehiclePosition.latitude(vp),
        "longitude" => VehiclePosition.longitude(vp),
        "bearing" => VehiclePosition.bearing(vp),
        "speed" => VehiclePosition.speed(vp)
      })

    drop_nil_values(%{
      "trip" => trip,
      "vehicle" => descriptor,
      "position" => position,
      "stop_id" => VehiclePosition.stop_id(vp),
      "current_stop_sequence" => VehiclePosition.stop_sequence(vp),
      "current_status" => VehiclePosition.status(vp) || "IN_TRANSIT_TO",
      "timestamp" => VehiclePosition.last_updated_truncated(vp),
      "occupancy_status" => VehiclePosition.occupancy_status(vp),
      "occupancy_percentage" => VehiclePosition.occupancy_percentage(vp),
      "multi_carriage_details" => VehiclePosition.multi_carriage_details(vp)
    })
  end

  defp optional_map(list, fun) when is_list(list) do
    Enum.map(list, fun)
  end

  defp optional_map(nil, _) do
    nil
  end

  defp build_consist(consist) do
    %{
      "label" => VehiclePositionConsist.label(consist)
    }
  end
end
