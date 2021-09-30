# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# Configures the endpoint
config :tr33_control, Tr33ControlWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "OjMmejtWRlJsOaBulT2hTUpx06835YTLQzx3H95MPV2X+M93hXrtJdxKASr/w5Mk",
  render_errors: [view: Tr33ControlWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Tr33Control.PubSub,
  live_view: [signing_salt: "HC+iC2aJ"]

config :tr33_control,
  serial_port: System.get_env("SERIAL_PORT") || "ttyAMA0",
  udp_listen_port: 1337,
  cache_persist_dir: System.get_env("CACHE_PERSIST_DIR") || "/root/tr33/cache_persist",
  command_max_index: 8,
  command_type_blacklist: [:pixel, :pixel_rgb, :mapped_triangle, :twang, :beat_equalizer],
  active_targets: [:wand, :ranken],
  targets: %{
    wand: %{
      area: :home,
      hosts: ["wand.fritz.box"]
    },
    tr33: %{
      area: :upstairs,
      hosts: ["tr33_esp32.lan.xhain.space"],
      strip_indices: [
        :all,
        :all_trunks,
        :all_branches,
        :trunk_1,
        :trunk_2,
        :trunk_3,
        :trunk_4,
        :trunk_5,
        :trunk_6,
        :trunk_7,
        :trunk_8,
        :branch_1,
        :branch_2,
        :branch_3,
        :branch_4,
        :branch_5,
        :branch_6,
        :branch_7,
        :branch_8,
        :branch_9,
        :branch_10,
        :branch_11,
        :branch_12
      ]
    },
    wolken: %{
      area: :upstairs,
      hosts: [
        "wolke1.lan.xhain.space",
        "wolke2.lan.xhain.space",
        "wolke3.lan.xhain.space",
        "wolke4.lan.xhain.space",
        "wolke5.lan.xhain.space",
        "wolke6.lan.xhain.space",
        "wolke7.lan.xhain.space",
        "wolke8.lan.xhain.space"
      ],
      strip_indices: [
        :all,
        :wolke_1,
        :wolke_2,
        :wolke_3,
        :wolke_4,
        :wolke_5,
        :wolke_6,
        :wolke_7,
        :wolke_8
      ]
    },
    trommel: %{
      area: :upstairs,
      hosts: ["trommel.lan.xhain.space"]
    },
    ranken: %{
      area: :downstairs,
      hosts: ["ranken.lan.xhain.space"],
      strip_indices: [
        :all,
        :strip_1,
        :strip_2,
        :strip_3,
        :strip_4,
        :strip_5,
        :strip_6,
        :strip_7,
        :strip_8,
        :strip_9,
        :strip_10
      ]
    },
    scubar: %{
      area: :downstairs,
      hosts: ["scubar.lan.xhain.space"]
    }
  }

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :nerves_leds, names: [green: "led0", red: "led1"]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
