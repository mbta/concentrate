defmodule Concentrate.Encoder.VehiclePositionsEnhanced do
  @moduledoc """
  Encodes a list of parsed data into a VehiclePositions_enhanced.json file.
  """
  @behaviour Concentrate.Encoder
  alias TransitRealtime, as: GTFS
  alias TransitRealtime.Consist
  alias TransitRealtime.FeedEntity
  alias TransitRealtime.FeedMessage
  alias TransitRealtime.Position
  alias TransitRealtime.VehicleDescriptor
  alias TransitRealtime.VehiclePosition
  alias TransitRealtime.VehiclePosition.CarriageDetails
  alias Concentrate.{TripDescriptor, VehiclePosition}
  alias VehiclePosition.Consist, as: VehiclePositionConsist
  import Concentrate.Encoder.GTFSRealtimeHelpers
  import Concentrate.Encoder.VehiclePositions, only: [entity_id: 1, trip_descriptor: 1]

  @impl Concentrate.Encoder
  def encode_groups(groups, opts \\ []) when is_list(groups) do
    message = %FeedMessage{
      header: feed_header(opts),
      entity: Enum.flat_map(groups, &build_entity/1)
    }

    Protobuf.JSON.encode!(message)
  end

  def build_entity({%TripDescriptor{} = td, vps, _stus}) do
    trip = trip_descriptor(td)

    for vp <- vps do
      %FeedEntity{
        id: entity_id(vp),
        vehicle: build_vehicle(vp, trip)
      }
    end
  end

  def build_entity({nil, vps, _stus}) do
    # vehicles without a trip
    for vp <- vps,
        trip_id = VehiclePosition.trip_id(vp),
        not is_nil(trip_id) do
      trip = %GTFS.TripDescriptor{
        trip_id: trip_id,
        schedule_relationship: :UNSCHEDULED
      }

      %FeedEntity{
        id: entity_id(vp),
        vehicle: build_vehicle(vp, trip)
      }
    end
  end

  @spec build_vehicle(VehiclePosition.t(), GTFS.TripDescriptor.t()) :: GTFS.VehiclePosition.t()
  def build_vehicle(%VehiclePosition{} = vp, trip) do
    descriptor =
      %VehicleDescriptor{
        id: VehiclePosition.id(vp),
        label: VehiclePosition.label(vp),
        license_plate: VehiclePosition.license_plate(vp)
      }
      |> VehicleDescriptor.put_extension(
        TransitRealtime.PbExtension,
        :consist,
        optional_map(VehiclePosition.consist(vp), &build_consist/1)
      )

    position =
      %Position{
        latitude: VehiclePosition.latitude(vp),
        longitude: VehiclePosition.longitude(vp),
        bearing: VehiclePosition.bearing(vp),
        speed: VehiclePosition.speed(vp)
      }

    mcd = VehiclePosition.multi_carriage_details(vp)

    %GTFS.VehiclePosition{
      trip: trip,
      vehicle: descriptor,
      position: position,
      stop_id: VehiclePosition.stop_id(vp),
      current_stop_sequence: VehiclePosition.stop_sequence(vp),
      current_status: VehiclePosition.status(vp) || :IN_TRANSIT_TO,
      timestamp: VehiclePosition.last_updated_truncated(vp),
      occupancy_status: VehiclePosition.occupancy_status(vp),
      occupancy_percentage: VehiclePosition.occupancy_percentage(vp),
      multi_carriage_details: mcd && Enum.map(mcd, &struct!(CarriageDetails, &1))
    }
  end

  defp optional_map(list, fun) when is_list(list) do
    Enum.map(list, fun)
  end

  defp optional_map(nil, _) do
    nil
  end

  defp build_consist(consist) do
    %Consist{
      label: VehiclePositionConsist.label(consist)
    }
  end
end
