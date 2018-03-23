# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :logger, level: :debug

config :ex_aws, json_codec: Jason

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
    Concentrate.Filter.ClosedStop
  ],
  group_filters: [
    Concentrate.GroupFilter.TimeOutOfRange,
    Concentrate.GroupFilter.RemoveUnneededTimes,
    Concentrate.GroupFilter.VehiclePastStop,
    Concentrate.GroupFilter.VehicleBeforeStop,
    Concentrate.GroupFilter.Shuttle,
    Concentrate.GroupFilter.SkippedDepartures,
    Concentrate.GroupFilter.CancelledTrip,
    Concentrate.GroupFilter.VehicleAtSkippedStop,
    Concentrate.GroupFilter.SkippedStopOnAddedTrip
  ],
  reporters: [
    Concentrate.Reporter.VehicleLatency,
    Concentrate.Reporter.StopTimeUpdateLatency,
    Concentrate.Reporter.Latency,
    Concentrate.Reporter.VehicleGoingFirstStop
  ],
  encoders: [
    files: [
      {"TripUpdates.pb", Concentrate.Encoder.TripUpdates},
      {"TripUpdates.json", Concentrate.Encoder.TripUpdates.JSON},
      {"VehiclePositions.pb", Concentrate.Encoder.VehiclePositions},
      {"VehiclePositions.json", Concentrate.Encoder.VehiclePositions.JSON},
      {"TripUpdates_enhanced.json", Concentrate.Encoder.TripUpdatesEnhanced}
    ]
  ],
  sinks: [
    filesystem: [directory: "/tmp"]
  ],
  file_tap: [
    enabled?: false
  ]

import_config "#{Mix.env()}.exs"
