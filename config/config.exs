# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

log_level =
  case Mix.env() do
    :test -> :warn
    _ -> :info
  end

config :logger, level: log_level
