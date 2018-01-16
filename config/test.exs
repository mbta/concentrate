use Mix.Config

config :logger, level: :info
config :logger, :console, level: :warn

config :concentrate, :sink_s3, ex_aws: Concentrate.TestExAws
