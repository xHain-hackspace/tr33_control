import Config

config :tr33_control, Tr33ControlWeb.Endpoint,
  url: [host: "tr33", port: 80],
  cache_static_manifest: "priv/static/cache_manifest.json",
  http: [
    port: 80,
    transport_options: [socket_opts: [:inet6]]
  ],
  server: true,
  check_origin: false

config :logger, level: :info
