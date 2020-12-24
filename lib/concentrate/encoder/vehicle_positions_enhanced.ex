defmodule Concentrate.Encoder.VehiclePositionsEnhanced do
  @moduledoc """
  Encodes a list of parsed data into a VehiclePositions.pb file.
  """
  @behaviour Concentrate.Encoder
  alias Concentrate.{TripDescriptor, VehiclePosition}
  alias VehiclePosition.Consist, as: VehiclePositionConsist
  import Concentrate.Encoder.GTFSRealtimeHelpers
  import Concentrate.Encoder.VehiclePositions, only: [entity_id: 1, trip_descriptor: 1]

  @impl Concentrate.Encoder
  def encode_groups(groups) when is_list(groups) do
    message = %{
      "header" => feed_header(),
      "entity" => Enum.flat_map(groups, &build_entity/1)
    }

    Jason.encode!(message)
  end

  def build_entity({%TripDescriptor{} = td, vps, _stus}) do
    trip = trip_descriptor(td)

    for vp <- vps do
      %{
        "id" => entity_id(vp),
        "vehicle" => build_vehicle(vp, trip)
      }
    end
  end

  def build_entity({nil, vps, _stus}) do
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
      "current_status" => VehiclePosition.status(vp),
      "timestamp" => VehiclePosition.last_updated(vp),
      "occupancy_status" => VehiclePosition.occupancy_status(vp),
      "occupancy_percentage" => VehiclePosition.occupancy_percentage(vp)
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
