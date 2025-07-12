import Config

config :premiere_ecoute,
  # twitch_api: PremiereEcouteMock.TwitchApi.Mock,
  twitch_api_base_url: "http://localhost:4001"

config :premiere_ecoute, PremiereEcoute.Repo,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :premiere_ecoute, PremiereEcouteWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PORT") || "4000")],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "z8umndtKIMuJVwT+jkgJ9QCmnxfUlIb2kzuMhx5qKvlFpvznpzES3xBI1tHempmd",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:premiere_ecoute, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:premiere_ecoute, ~w(--watch)]}
  ]

config :premiere_ecoute, PremiereEcouteWeb.Endpoint,
  live_reload: [
    web_console_logger: true,
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/premiere_ecoute_web/(?:controllers|live|components|router)/?.*\.(ex|heex)$"
    ]
  ]

config :premiere_ecoute, dev_routes: true

config :logger, :default_formatter, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20

config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  debug_heex_annotations: true,
  enable_expensive_runtime_checks: true
