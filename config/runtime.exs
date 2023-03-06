import Config

is_prod? = config_env() == :prod
is_release? = not is_nil(System.get_env("RELEASE_MODE"))

if is_prod? and is_release? do
  sentry_env = System.get_env("SENTRY_ENV")

  if not is_nil(sentry_env) do
    config :sentry,
      dsn: System.fetch_env!("SENTRY_DSN"),
      environment_name: sentry_env,
      enable_source_code_context: true,
      root_source_code_path: File.cwd!(),
      tags: %{
        env: sentry_env
      },
      included_environments: [sentry_env]

    config :logger, Sentry.LoggerBackend,
      level: :error,
      capture_log_messages: true
  end
end
