defmodule Concentrate.Encoder.TripUpdatesEnhanced do
  @moduledoc """
  Encodes a list of parsed data into an enhanced.pb file.
  """
  @behaviour Concentrate.Encoder
  alias Concentrate.{StopTimeUpdate, TripDescriptor}
  import Concentrate.Encoder.GTFSRealtimeHelpers

  @impl Concentrate.Encoder
  def encode_groups(groups, opts \\ []) when is_list(groups) do
    message = %{
      header: feed_header(opts),
      entity: trip_update_feed_entity(groups, &build_stop_time_update/1, &enhanced_data/1)
    }

    Jason.encode!(message)
  end

  defp enhanced_data(update) do
    %{
      route_pattern_id: TripDescriptor.route_pattern_id(update),
      revenue: TripDescriptor.revenue(update),
      last_trip: TripDescriptor.last_trip(update),
      update_type: TripDescriptor.update_type(update)
    }
  end

  defp build_stop_time_update(update) do
    drop_nil_values(%{
      stop_id: StopTimeUpdate.stop_id(update),
      stop_sequence: StopTimeUpdate.stop_sequence(update),
      arrival: determine_arrival_value(update),
      departure: determine_departure_value(update),
      passthrough_time: StopTimeUpdate.passthrough_time(update),
      schedule_relationship: schedule_relationship(StopTimeUpdate.schedule_relationship(update)),
      boarding_status: StopTimeUpdate.status(update),
      platform_id: StopTimeUpdate.platform_id(update)
    })
  end

  defp determine_arrival_value(%{passthrough_time: nil} = update),
    do: stop_time_event(StopTimeUpdate.arrival_time(update), StopTimeUpdate.uncertainty(update))

  defp determine_arrival_value(_), do: nil

  defp determine_departure_value(%{passthrough_time: nil} = update),
    do: stop_time_event(StopTimeUpdate.departure_time(update), StopTimeUpdate.uncertainty(update))

  defp determine_departure_value(_), do: nil
end
