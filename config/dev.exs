import Config

config :premiere_ecoute, PremiereEcoute.Apis,
  twitch: [
    api: PremiereEcoute.Apis.Streaming.TwitchApi,
    urls: [
      api: "http://localhost:4001",
      # api: "https://api.twitch.tv/helix",
      accounts: "https://id.twitch.tv/oauth2"
    ]
  ],
  spotify: [
    api: PremiereEcoute.Apis.MusicProvider.SpotifyApi,
    urls: [
      api: "https://api.spotify.com/v1",
      accounts: "https://accounts.spotify.com/api"
    ]
  ],
  deezer: [
    api: PremiereEcoute.Apis.MusicProvider.DeezerApi,
    urls: [
      api: "https://api.deezer.com/"
    ]
  ]

config :premiere_ecoute, PremiereEcoute.Sessions, vote_cooldown: 15

config :premiere_ecoute, PremiereEcoute.Repo,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :premiere_ecoute, PremiereEcoute.Telemetry.PromEx,
  manual_metrics_start_delay: :no_delay,
  drop_metrics_groups: [],
  grafana: [
    host: "http://localhost:3000",
    auth_token: "",
    upload_dashboards_on_start: true,
    folder_name: "Premiere Ecoute",
    annotate_app_lifecycle: true
  ]

config :premiere_ecoute, PremiereEcouteWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "z8umndtKIMuJVwT+jkgJ9QCmnxfUlIb2kzuMhx5qKvlFpvznpzES3xBI1tHempmd",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:premiere_ecoute, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:premiere_ecoute, ~w(--watch)]},
    storybook_tailwind: {Tailwind, :install_and_run, [:storybook, ~w(--watch)]}
  ]

config :premiere_ecoute, PremiereEcouteWeb.Endpoint,
  live_reload: [
    web_console_logger: true,
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/premiere_ecoute_web/(?:controllers|live|components|router)/?.*\.(ex|heex)$",
      ~r"storybook/.*(exs)$"
    ]
  ]

# config :premiere_ecoute, PremiereEcoute.Mailer, adapter: Swoosh.Adapters.Local

config :premiere_ecoute, dev_routes: true

config :logger, level: :info

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
config :phoenix_live_view, debug_heex_annotations: true, enable_expensive_runtime_checks: true
