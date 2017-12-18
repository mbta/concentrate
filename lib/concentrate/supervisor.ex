defmodule Concentrate.Supervisor do
  @moduledoc """
  Supervisor for Concentrate.

  Children:
  * one per file we're fetching
  * one per type of output file (currently 2 TripUpdates and 2 VehiclePositions)
  * one per uploaded/saved file
  * one to merge multiple files into a single output stream
  """
  def start_link do
    Supervisor.start_link(children(), strategy: :one_for_one)
  end

  def children do
    _ =
      Enum.concat([
        fetch_children(),
        [
          {Concentrate.MergeProducerConsumer, [
            producers: [:vehicle_positions, :trip_updates]
          ]}
        ],
        output_children(),
        upload_children()
      ])

    []
  end

  defp fetch_children do
    [
      {Concentrate.Producer.HTTP, [
        "http://developer.mbta.com/lib/GTRTFS/Alerts/VehiclePositions.pb",
        [
          name: :vehicle_positions,
          parser: Concentrate.Parser.GTFSRealtime
        ]
      ]},
      {Concentrate.Producer.HTTP, [
        "http://developer.mbta.com/lib/GTRTFS/Alerts/TripUpdates.pb",
        [
          name: :trip_updates,
          parser: Concentrate.Parser.GTFSRealtime
        ]
      ]}
    ]
  end

  defp output_children do
    []
  end

  defp upload_children do
    []
  end
end
