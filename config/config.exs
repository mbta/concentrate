# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :logger, level: :debug

config :ex_aws, json_codec: Jason

# per https://github.com/edgurgel/httpoison/issues/130, set the SSL version to pick a better default
config :ssl, protocol_version: :"tlsv1.2"

config :concentrate,
  sources: [
    gtfs_realtime: [
      vehicle_positions: "https://cdn.mbta.com/realtime/VehiclePositions.pb",
      trip_updates: "https://cdn.mbta.com/realtime/TripUpdates.pb"
    ]
  ],
  alerts: [
    url: "https://cdn.mbta.com/realtime/Alerts.pb"
  ],
  gtfs: [
    url: "https://cdn.mbta.com/MBTA_GTFS.zip"
  ],
  filters: [
    Concentrate.Filter.NullStopSequence,
    Concentrate.Filter.VehicleWithNoTrip,
    Concentrate.Filter.RoundSpeedAndBearing,
    Concentrate.Filter.IncludeRouteDirection,
    Concentrate.Filter.IncludeStopID
  ],
  group_filters: [
    Concentrate.GroupFilter.TimeOutOfRange,
    Concentrate.GroupFilter.RemoveUnneededTimes,
    Concentrate.GroupFilter.Shuttle,
    Concentrate.GroupFilter.SkippedDepartures,
    Concentrate.GroupFilter.CancelledTrip,
    Concentrate.GroupFilter.ClosedStop,
    Concentrate.GroupFilter.VehicleAtSkippedStop,
    Concentrate.GroupFilter.VehicleStopMatch,
    Concentrate.GroupFilter.SkippedStopOnAddedTrip,
    Concentrate.GroupFilter.TripDescriptorTimestamp
  ],
  reporters: [
    Concentrate.Reporter.VehicleLatency,
    Concentrate.Reporter.StopTimeUpdateLatency,
    Concentrate.Reporter.Latency
  ],
  encoders: [
    files: [
      {"TripUpdates.pb", Concentrate.Encoder.TripUpdates},
      {"TripUpdates.json", Concentrate.Encoder.TripUpdates.JSON},
      {"VehiclePositions.pb", Concentrate.Encoder.VehiclePositions},
      {"VehiclePositions.json", Concentrate.Encoder.VehiclePositions.JSON},
      {"TripUpdates_enhanced.json", Concentrate.Encoder.TripUpdatesEnhanced},
      {"VehiclePositions_enhanced.json", Concentrate.Encoder.VehiclePositionsEnhanced}
    ]
  ],
  sinks: [
    filesystem: [directory: "/tmp"]
  ],
  file_tap: [
    enabled?: false
  ],
  http_producer: Concentrate.Producer.HTTPoison

import_config "#{Mix.env()}.exs"
