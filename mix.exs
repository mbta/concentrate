defmodule Concentrate.MixProject do
  use Mix.Project

  def project do
    [
      app: :concentrate,
      version: "0.1.0",
      elixir: "~> 1.5 or ~> 1.6-dev",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test, "coveralls.html": :test, "coveralls.json": :test],
      dialyzer: [ignore_warnings: ".dialyzer.ignore-warnings"],
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases do
    [test: "test --no-start"]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger | env_applications(Mix.env())],
      mod: {Concentrate, []}
    ]
  end

  defp env_applications(:prod) do
    [:sasl]
  end

  defp env_applications(_) do
    []
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:benchee, ">= 0.0.0", runtime: false, only: :dev},
      {:bypass, "~> 0.8", only: :test},
      {:credo, "~> 0.8", runtime: false, only: :dev},
      {:csv, "~> 2.1"},
      {:dialyxir, "~> 0.5", runtime: false, only: :dev},
      {:distillery, "~> 1.4", runtime: false, only: :prod},
      {:ehmon, git: "https://github.com/heroku/ehmon.git", tag: "v4", only: :prod},
      {:ex_aws, "~> 2.0"},
      {:ex_aws_s3, "~> 2.0"},
      {:excoveralls, "~> 0.7", only: :test},
      {:exprotobuf, "~> 1.2"},
      {:gen_stage, "~> 0.12"},
      {:gtfs_realtime_viz, "~> 0.5"},
      {:httpoison, "~> 0.13"},
      {:poison, "~> 3.1"},
      {:stream_data, "~> 0.4", only: :test}
    ]
  end
end
