defmodule Concentrate.MixProject do
  use Mix.Project

  def project do
    [
      app: :concentrate,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: LcovEx, output: "coverage", ignore_paths: ~w(test/ src/)],
      dialyzer: [
        plt_add_deps: :transitive,
        flags: [
          :race_conditions,
          :unmatched_returns,
          :underspecs,
          :unknown
        ],
        ignore_warnings: ".dialyzer.ignore-warnings"
      ],
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
      releases: releases()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases do
    [test: "test --no-start"]
  end

  defp releases do
    [
      concentrate: [
        applications: [concentrate: :permanent, ex_aws: :permanent]
      ]
    ]
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
      {:benchee, "~> 1.0", runtime: false, only: :dev},
      {:bypass, "~> 2.1", only: :test},
      {:credo, "~> 1.0", runtime: false, only: :dev},
      {:csv, "~> 2.1"},
      {:dialyxir, "~> 1.0", runtime: false, only: :dev},
      {:ehmon, git: "https://github.com/mbta/ehmon.git", branch: "master", only: ~w(test prod)a},
      {:ex_aws, "~> 2.4"},
      {:ex_aws_s3, "~> 2.3"},
      {:lcov_ex, "~> 0.2.0", only: :test, runtime: false},
      {:gen_stage, "~> 1.0"},
      {:gpb, "~> 4.7", only: :dev, runtime: false, only: :dev},
      {:httpoison, "~> 1.0"},
      {:jason, "~> 1.0"},
      {:stream_data, "~> 0.4", only: :test},
      {:tzdata, "~> 1.1.1"}
    ]
  end
end
