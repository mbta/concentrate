use Mix.Config

config :logger,
  level: :info,
  backends: []

config :concentrate, :sink_s3, ex_aws: Concentrate.TestExAws
