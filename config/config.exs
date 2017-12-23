# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

log_level =
  case Mix.env() do
    :test -> :warn
    _ -> :info
  end

config :logger, level: log_level

config :concentrate,
  sources: [
    gtfs_realtime: [
      vehicle_positions: "http://developer.mbta.com/lib/GTRTFS/Alerts/VehiclePositions.pb",
      trip_updates: "http://developer.mbta.com/lib/GTRTFS/Alerts/TripUpdates.pb"
    ]
  ],
  gtfs: [
    url: "https://www.mbta.com/uploadedfiles/MBTA_GTFS.zip"
  ],
  filters: [
    Concentrate.Filter.VehicleWithNoTrip,
    Concentrate.Filter.RoundSpeedToInteger,
    Concentrate.Filter.IncludeRouteDirection
  ],
  encoders: [
    files: [
      {"TripUpdates.pb", Concentrate.Encoder.TripUpdates},
      {"VehiclePositions.pb", Concentrate.Encoder.VehiclePositions}
    ]
  ],
  sinks: [
    filesystem: [directory: "/tmp"]
  ]

import_config "*.local.exs"
