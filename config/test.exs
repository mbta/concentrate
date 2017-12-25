use Mix.Config

config :logger, level: :warn

config :concentrate, :sink_s3, ex_aws: Concentrate.TestExAws
