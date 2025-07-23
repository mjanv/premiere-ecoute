import Config

config :premiere_ecoute,
  environment: config_env(),
  ecto_repos: [PremiereEcoute.Repo],
  event_stores: [PremiereEcoute.EventStore],
  generators: [timestamp_type: :utc_datetime],
  handlers: [
    PremiereEcoute.Sessions.ListeningSession.CommandHandler,
    PremiereEcoute.Sessions.ListeningSession.EventHandler,
    PremiereEcoute.Sessions.Scores.EventHandler
  ]

config :premiere_ecoute, :scopes,
  user: [
    default: true,
    module: PremiereEcoute.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: PremiereEcoute.AccountsFixtures,
    test_login_helper: :register_and_log_in_user
  ]

config :premiere_ecoute, PremiereEcouteWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: PremiereEcouteWeb.Errors.ErrorHTML, json: PremiereEcouteWeb.Errors.ErrorJSON],
    layout: false
  ],
  pubsub_server: PremiereEcoute.PubSub,
  live_view: [signing_salt: "6RkVNFmy"]

config :premiere_ecoute, PremiereEcoute.Repo, adapter: Ecto.Adapters.Postgres

config :premiere_ecoute, PremiereEcoute.EventStore,
  column_data_type: "jsonb",
  serializer: EventStore.JsonbSerializer,
  types: EventStore.PostgresTypes

config :premiere_ecoute, PremiereEcoute.Telemetry.PromEx,
  disabled: false,
  manual_metrics_start_delay: :no_delay,
  drop_metrics_groups: [],
  grafana: :disabled,
  metrics_server: :disabled

config :esbuild,
  version: "0.17.11",
  premiere_ecoute: [
    args: ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  version: "4.0.9",
  premiere_ecoute: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

config :sentry,
  environment_name: Mix.env(),
  enable_source_code_context: true,
  root_source_code_paths: [File.cwd!()]

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason
config :phoenix, :logger, false

config :premiere_ecoute, PremiereEcouteWeb.Gettext,
  locales: ~w(en fr it),
  default_locale: "en"

config :ueberauth, Ueberauth,
  providers: [
    twitch: {Ueberauth.Strategy.Twitch, []},
    spotify:
      {Ueberauth.Strategy.Spotify,
       [
         default_scope:
           "user-read-private user-read-email user-read-playback-state user-modify-playback-state user-read-currently-playing"
       ]}
  ]

import_config "#{config_env()}.exs"
