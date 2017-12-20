defmodule Concentrate.Supervisor do
  @moduledoc """
  Supervisor for Concentrate.

  Children:
  * one per file we're fetching
  * one per type of output file (currently 2 TripUpdates and 2 VehiclePositions)
  * one per uploaded/saved file
  * one to merge multiple files into a single output stream
  """
  import Supervisor, only: [child_spec: 2]

  def start_link do
    Supervisor.start_link(children(), strategy: :one_for_one)
  end

  def children do
    [
      child_spec(
        {
          Concentrate.Producer.HTTP,
          {
            "http://developer.mbta.com/lib/GTRTFS/Alerts/VehiclePositions.pb",
            name: :vehicle_positions, parser: Concentrate.Parser.GTFSRealtime
          }
        },
        id: :vehicle_positions
      ),
      child_spec(
        {
          Concentrate.Producer.HTTP,
          {
            "http://developer.mbta.com/lib/GTRTFS/Alerts/TripUpdates.pb",
            name: :trip_updates, parser: Concentrate.Parser.GTFSRealtime
          }
        },
        id: :trip_updates
      ),
      {Concentrate.Merge.ProducerConsumer, [
        name: :merge,
        subscribe_to: [:vehicle_positions, :trip_updates]
      ]},
      {Concentrate.Encoder.ProducerConsumer, [
        name: :file_output,
        files: [
          {"TripUpdates.pb", Concentrate.Encoder.TripUpdates},
          {"VehiclePositions.pb", Concentrate.Encoder.VehiclePositions}
        ],
        subscribe_to: [:merge]
      ]},
      {Concentrate.Sink.Filesystem, [
        directory: "/tmp",
        subscribe_to: [:file_output]
      ]}
    ]
  end
end
