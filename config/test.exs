import Config

config :logger,
  level: :info,
  backends: [],
  always_evaluate_messages: true

config :concentrate, :group_filters, [
  {Concentrate.GroupFilter.ScheduledStopTimes, on_time_statuses: ["on time"]},
  Concentrate.GroupFilter.RemoveUncertainStopTimeUpdates
]

config :concentrate, :sink_s3, ex_aws: Concentrate.TestExAws

config :concentrate,
  screenplay_stops_config: [
    url: "http://127.0.0.1/api/suppressed-predictions/suppression_data",
    api_key: "screenplay_api_key_for_testing"
  ]
