defmodule Concentrate.Encoder.VehiclePositions do
  @moduledoc """
  Encodes a list of parsed data into a VehiclePositions.pb file.
  """
  @behaviour Concentrate.Encoder
  alias Concentrate.{TripDescriptor, VehiclePosition}
  import Concentrate.Encoder.GTFSRealtimeHelpers

  @impl Concentrate.Encoder
  def encode_groups(groups, opts \\ []) when is_list(groups) do
    message = %{
      header: feed_header(opts),
      entity: Enum.flat_map(groups, &build_entity/1)
    }

    :gtfs_realtime_proto.encode_msg(message, :FeedMessage)
  end

  def feed_entity(list) do
    list
    |> group
    |> Enum.flat_map(&build_entity/1)
  end

  def build_entity({%TripDescriptor{} = td, vps, _stus}) do
    trip = trip_descriptor(td)

    for vp <- vps do
      %{
        id: entity_id(vp),
        vehicle: build_vehicle(vp, trip)
      }
    end
  end

  def build_entity({nil, vps, _stus}) do
    # vehicles without a trip
    for vp <- vps do
      trip =
        if trip_id = VehiclePosition.trip_id(vp) do
          %{
            trip_id: trip_id,
            schedule_relationship: :UNSCHEDULED
          }
        end

      %{
        id: entity_id(vp),
        vehicle: build_vehicle(vp, trip)
      }
    end
  end

  defp build_vehicle(%VehiclePosition{} = vp, trip) do
    descriptor =
      drop_nil_values(%{
        id: VehiclePosition.id(vp),
        label: VehiclePosition.label(vp),
        license_plate: VehiclePosition.license_plate(vp)
      })

    position =
      drop_nil_values(%{
        latitude: VehiclePosition.latitude(vp),
        longitude: VehiclePosition.longitude(vp),
        bearing: VehiclePosition.bearing(vp),
        speed: VehiclePosition.speed(vp)
      })

    drop_nil_values(%{
      trip: trip,
      vehicle: descriptor,
      position: position,
      stop_id: VehiclePosition.stop_id(vp),
      current_stop_sequence: VehiclePosition.stop_sequence(vp),
      current_status: VehiclePosition.status(vp) || :IN_TRANSIT_TO,
      timestamp: VehiclePosition.last_updated_truncated(vp),
      occupancy_status: VehiclePosition.occupancy_status(vp),
      occupancy_percentage: VehiclePosition.occupancy_percentage(vp),
      multi_carriage_details:
        build_carriage_details_struct(VehiclePosition.multi_carriage_details(vp))
    })
  end

  defp build_carriage_details_struct(nil) do
    nil
  end

  # Convert to atomized keys, so that both atoms and string keys are supported:
  defp get_atomized_carriage_details(carriage_details) do
    atomized_carriage_details =
      for {key, val} <- carriage_details,
          into: %{},
          do: {if(is_atom(key), do: key, else: String.to_atom(key)), val}

    unatomized_occupancy_status =
      if Map.has_key?(atomized_carriage_details, :occupancy_status),
        do: atomized_carriage_details.occupancy_status,
        else: nil

    %{
      id:
        if(Map.has_key?(atomized_carriage_details, :id),
          do: atomized_carriage_details.id,
          else: nil
        ),
      label:
        if(Map.has_key?(atomized_carriage_details, :label),
          do: atomized_carriage_details.label,
          else: nil
        ),
      carriage_sequence:
        if(Map.has_key?(atomized_carriage_details, :carriage_sequence),
          do: atomized_carriage_details.carriage_sequence,
          else: nil
        ),
      occupancy_status:
        if(is_atom(unatomized_occupancy_status),
          do: unatomized_occupancy_status,
          else: String.to_atom(unatomized_occupancy_status)
        ),
      occupancy_percentage:
        if(Map.has_key?(atomized_carriage_details, :occupancy_percentage),
          do: atomized_carriage_details.occupancy_percentage,
          else: nil
        )
    }
  end

  # Ensures that the nil / empty values are appropriate as per PB spec:
  defp build_carriage_details_struct(multi_carriage_details) do
    Enum.map(multi_carriage_details, fn carriage_details ->
      %{
        id: id,
        label: label,
        carriage_sequence: carriage_sequence,
        occupancy_status: occupancy_status,
        occupancy_percentage: occupancy_percentage
      } = get_atomized_carriage_details(carriage_details)

      # Assign safe default values to the expected struct so the values don't get swallowed:
      %Concentrate.VehiclePosition.CarriageDetails{
        id: if(id == nil, do: "", else: id),
        label: if(label == nil, do: "", else: label),
        carriage_sequence: if(carriage_sequence == nil, do: 1, else: carriage_sequence),
        occupancy_status:
          if(occupancy_status == nil,
            do: :NO_DATA_AVAILABLE,
            else: occupancy_status
          ),
        occupancy_percentage: if(occupancy_percentage == nil, do: -1, else: occupancy_percentage)
      }
    end)
  end

  def entity_id(vp) do
    VehiclePosition.id(vp) || VehiclePosition.trip_id(vp) ||
      Integer.to_string(:erlang.unique_integer())
  end

  def trip_descriptor(update) do
    drop_nil_values(%{
      trip_id: TripDescriptor.trip_id(update),
      route_id: TripDescriptor.route_id(update),
      direction_id: TripDescriptor.direction_id(update),
      start_time: TripDescriptor.start_time(update),
      start_date: encode_date(TripDescriptor.start_date(update)),
      schedule_relationship: TripDescriptor.schedule_relationship(update)
    })
  end
end
