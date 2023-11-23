# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :tr33_control,
  serial_port: System.get_env("SERIAL_PORT") || "ttyAMA0",
  udp_listen_port: 1337,
  command_max_count: 8,
  command_blacklist: [
    :pixel,
    :pixel_rgb,
    :beat_equalizer,
    :mapped_triangle,
    :mapped_ping_pong,
    :debug,
    :calibrate,
    :fairy_light,
    :twang
  ],
  command_priority: [
    :rainbow,
    :rain,
    :sparkle,
    :pixel_func,
    :ping_pong,
    :single_color,
    :gravity,
    :flicker_sparkle,
    :mapped_shape,
    :mapped_slope,
    :mapped_particles,
    :render,
    :kaleidoscope,
    :white
  ],
  add_mock_targets: false,
  target_configs: %{
    tr33: %{},
    wolken: %{
      name_regex: ~r/Wolke/
    },
    ranken: %{},
    wand: %{},
    dev: %{
      name_regex: ~r/dev/
    }
  }

# Configures the endpoint
config :tr33_control, Tr33ControlWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "OjMmejtWRlJsOaBulT2hTUpx06835YTLQzx3H95MPV2X+M93hXrtJdxKASr/w5Mk",
  render_errors: [
    formats: [html: Tr33ControlWeb.ErrorHTML, json: Tr33ControlWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Tr33Control.PubSub,
  live_view: [signing_salt: "HC+iC2aJ"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :nerves_leds, names: [green: "led0", red: "led1"]

config :dart_sass,
  version: "1.58.0",
  default: [
    args: ~w(css/app.scss ../priv/static/assets/app.css),
    cd: Path.expand("../assets", __DIR__)
  ]

config :esbuild,
  version: "0.14.41",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2016 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :sentry,
  environment_name: config_env(),
  included_environments: [:prod]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
