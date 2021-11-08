defmodule Tr33Control.MixProject do
  use Mix.Project

  def project do
    [
      app: :tr33_control,
      version: "0.1.0",
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
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
      {:phoenix, "~> 1.6.0"},
      {:phoenix_live_view, "~> 0.16"},
      {:phoenix_ecto, "~> 4.0"},
      {:phoenix_html, "~> 3.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_dashboard, "~> 0.5"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 0.5"},
      {:floki, "~> 0.0", only: :test},
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.0"},
      {:ecto, "~> 3.0"},
      {:circuits_uart, "~> 1.2"},
      {:nerves_leds, "~> 0.8"},
      {:input_event, "~> 1.0"},
      {:cachex, "~> 3.3"},
      {:sentry, "~> 8.0", runtime: false},
      {:exprotobuf, github: "reimerei/exprotobuf"}
    ]
  end

  defp aliases do
    []
  end
end
