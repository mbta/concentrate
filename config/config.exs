# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :logger, level: :debug

config :concentrate,
  sources: [
    gtfs_realtime: [
      vehicle_positions: "http://developer.mbta.com/lib/GTRTFS/Alerts/VehiclePositions.pb",
      trip_updates: "http://developer.mbta.com/lib/GTRTFS/Alerts/TripUpdates.pb"
    ]
  ],
  alerts: [
    url: "http://developer.mbta.com/lib/GTRTFS/Alerts/Alerts.pb"
  ],
  gtfs: [
    url: "https://www.mbta.com/uploadedfiles/MBTA_GTFS.zip"
  ],
  filters: [
    Concentrate.Filter.VehicleWithNoTrip,
    Concentrate.Filter.RoundSpeedToInteger,
    Concentrate.Filter.IncludeRouteDirection,
    Concentrate.Filter.RemoveUnneededTimes,
    Concentrate.Filter.ClosedStop,
    Concentrate.Filter.CancelledTrip
  ],
  encoders: [
    files: [
      {"TripUpdates.pb", Concentrate.Encoder.TripUpdates},
      {"VehiclePositions.pb", Concentrate.Encoder.VehiclePositions},
      {"TripUpdates_enhanced.json", Concentrate.Encoder.TripUpdatesEnhanced}
    ]
  ],
  sinks: [
    filesystem: [directory: "/tmp"]
  ]

import_config "#{Mix.env()}.exs"
