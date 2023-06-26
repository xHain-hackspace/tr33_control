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
  cache_persist_dir: System.get_env("CACHE_PERSIST_DIR") || "/root/tr33/cache_persist",
  command_max_count: 8,
  command_type_blacklist: [:pixel, :pixel_rgb, :mapped_triangle, :beat_equalizer, :mapped_ping_pong],
  add_mock_targets: false,
  target_configs: %{
    tr33:
      %{
        # strip_indices: [
        #   :all,
        #   :all_trunks,
        #   :all_branches,
        #   :trunk_1,
        #   :trunk_2,
        #   :trunk_3,
        #   :trunk_4,
        #   :trunk_5,
        #   :trunk_6,
        #   :trunk_7,
        #   :trunk_8,
        #   :branch_1,
        #   :branch_2,
        #   :branch_3,
        #   :branch_4,
        #   :branch_5,
        #   :branch_6,
        #   :branch_7,
        #   :branch_8,
        #   :branch_9,
        #   :branch_10,
        #   :branch_11,
        #   :branch_12
        # ]
      },
    wolken: %{
      name_regex: ~r/Wolke/
      # strip_indices: [
      #   :all,
      #   :wolke_1,
      #   :wolke_2,
      #   :wolke_3,
      #   :wolke_4,
      #   :wolke_5,
      #   :wolke_6,
      #   :wolke_7,
      #   :wolke_8,
      #   :wolke_9,
      #   :wolke_10,
      #   :wolke_11,
      #   :wolke_12,
      #   :wolke_13
      # ]
    },
    ranken:
      %{
        # strip_indices: [
        #   :all,
        #   :strip_1,
        #   :strip_2,
        #   :strip_3,
        #   :strip_4,
        #   :strip_5,
        #   :strip_6,
        #   :strip_7,
        #   :strip_8,
        #   :strip_9,
        #   :strip_10
        # ]
      },
    wand:
      %{
        # strip_indices: [
        #   :all,
        #   :foo,
        #   :baa
        # ]
      },
    dev: %{
      name_regex: ~r/dev/
    }
  }

# Configures the endpoint
config :tr33_control, Tr33ControlWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "OjMmejtWRlJsOaBulT2hTUpx06835YTLQzx3H95MPV2X+M93hXrtJdxKASr/w5Mk",
  render_errors: [
    formats: [html: SampleAppWeb.ErrorHTML, json: SampleAppWeb.ErrorJSON],
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
  version: "1.55.0",
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

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
