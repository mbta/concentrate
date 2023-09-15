import Config

config :logger,
  level: :info,
  backends: [],
  always_evaluate_messages: true

config :concentrate, :group_filters, [
  {Concentrate.GroupFilter.ScheduledStopTimes, on_time_statuses: ["on time"]}
]

config :concentrate, :sink_s3, ex_aws: Concentrate.TestExAws
