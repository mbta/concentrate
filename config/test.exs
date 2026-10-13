import Config

config :logger,
  level: :info,
  backends: [],
  always_evaluate_messages: true

config :concentrate, :group_filters, [
  {Concentrate.GroupFilter.ScheduledStopTimes, on_time_statuses: ["on time"]},
  Concentrate.GroupFilter.RemoveUncertainStopTimeUpdates,
  {Concentrate.GroupFilter.SuppressStopTimeUpdate,
   terminal_suppression_by_time: %{
     "place-matt" => %{
       1 => {~T[04:00:00], ~T[07:30:00]},
       2 => {~T[04:00:00], ~T[07:30:00]},
       3 => {~T[04:00:00], ~T[07:30:00]},
       4 => {~T[04:00:00], ~T[07:30:00]},
       5 => {~T[04:00:00], ~T[07:30:00]},
       6 => {~T[04:00:00], ~T[07:30:00]},
       7 => {~T[04:00:00], ~T[07:30:00]}
     }
   }}
]

config :concentrate, :sink_s3, ex_aws: Concentrate.TestExAws

config :concentrate,
  screenplay_stops_config: [
    url: "http://127.0.0.1/api/suppressed-predictions/suppression_data",
    api_key: "screenplay_api_key_for_testing"
  ]
