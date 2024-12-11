import Config

persist_dir = System.get_env("CACHE_PERSIST_DIR") || "presets"

config :tr33_control,
  cache_persist_dir: persist_dir

config :tr33_control, Tr33Control.Repo,
  database: Path.join(persist_dir, "tr33_control.db"),
  pool_size: 5

if config_env() == :prod do
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "localhost"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :tr33_control, Tr33ControlWeb.Endpoint,
    url: [host: host, port: 80, scheme: "http"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  config :sentry,
    dsn: System.get_env("SENTRY_DSN"),
    environment_name: config_env(),
    tags: %{
      env: "production",
      target: System.get_env("TARGET")
    },
    included_environments: [:prod]
end

case {System.fetch_env("MQTT_HOST"), System.fetch_env("MQTT_PASSWORD")} do
  {{:ok, mqtt_host}, {:ok, mqtt_password}} ->
    config :tr33_control, :mqtt_config,
      mqtt_host: mqtt_host,
      password: mqtt_password,
      client_id: "tr33_control"

  _ ->
    :noop
end
