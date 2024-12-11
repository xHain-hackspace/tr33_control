defmodule Tr33Control.MixProject do
  use Mix.Project

  def project do
    [
      app: :tr33_control,
      version: "0.1.0",
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      releases: releases()
    ]
  end

  def application do
    [
      mod: {Tr33Control.Application, []},
      extra_applications: [:logger, :runtime_tools, :os_mon]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.7"},
      {:phoenix_ecto, "~> 4.4"},
      {:ecto_sql, "~> 3.10"},
      {:ecto_sqlite3, ">= 0.0.0"},
      {:ecto_sqlite3_extras, "~> 1.2.0"},
      {:phoenix_html, "~> 3.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.20"},
      {:heroicons, "~> 0.5"},
      {:floki, ">= 0.30.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.7"},
      # {:swoosh, "~> 1.3"},
      # {:finch, "~> 0.13"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.5"},
      # own
      # {:circuits_uart, "~> 1.2"},
      {:nerves_leds, "~> 0.8"},
      # {:input_event, "~> 1.0"},
      {:cachex, "~> 3.3"},
      {:sentry, "~> 9.0"},
      {:hackney, "~> 1.8"},
      {:exprotobuf, github: "reimerei/exprotobuf"},
      {:esbuild, "~> 0.5", runtime: Mix.env() == :dev},
      {:dart_sass, "~> 0.3", runtime: Mix.env() == :dev},
      {:ex_homeassistant, github: "reimerei/ex_homeassistant"},
      {:tint, "~> 1.1"}
    ]
  end

  defp aliases do
    [
      "assets.deploy": [
        "esbuild default --minify",
        "sass default --no-source-map --style=compressed",
        "phx.digest"
      ]
    ]
  end

  defp releases do
    [
      tr33_control: [
        include_executables_for: [:unix],
        steps: [:assemble, :tar]
      ]
    ]
  end
end
