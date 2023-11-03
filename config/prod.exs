import Config

config :tr33_control, Tr33ControlWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  server: true,
  check_origin: false

config :logger, level: :info
