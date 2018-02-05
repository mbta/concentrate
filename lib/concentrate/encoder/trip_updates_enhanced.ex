defmodule Concentrate.Encoder.TripUpdatesEnhanced do
  @moduledoc """
  Encodes a list of parsed data into an enhanced.pb file.
  """
  @behaviour Concentrate.Encoder
  alias Concentrate.StopTimeUpdate
  import Concentrate.Encoder.GTFSRealtimeHelpers

  @impl Concentrate.Encoder
  def encode(list) when is_list(list) do
    message = %{
      header: feed_header(),
      entity: trip_update_feed_entity(list, &build_stop_time_update/1)
    }

    Jason.encode!(message)
  end

  defp build_stop_time_update(update) do
    drop_nil_values(%{
      stop_id: StopTimeUpdate.stop_id(update),
      stop_sequence: StopTimeUpdate.stop_sequence(update),
      arrival: stop_time_event(StopTimeUpdate.arrival_time(update)),
      departure: stop_time_event(StopTimeUpdate.departure_time(update)),
      schedule_relationship: StopTimeUpdate.schedule_relationship(update),
      boarding_status: StopTimeUpdate.status(update),
      platform_id: StopTimeUpdate.platform_id(update)
    })
  end
end
