use Mix.Config

config :logger,
  level: :info,
  backends: []

config :concentrate, :group_filters, [
  {Concentrate.GroupFilter.ScheduledStopTimes, on_time_statuses: ["on time"]}
]

config :concentrate, :sink_s3, ex_aws: Concentrate.TestExAws
