import Config

config :premiere_ecoute, :scopes,
  accounts_user: [
    default: false,
    module: PremiereEcoute.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: PremiereEcoute.AccountsFixtures,
    test_login_helper: :register_and_log_in_user
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

config :premiere_ecoute,
  ecto_repos: [PremiereEcoute.Repo],
  generators: [timestamp_type: :utc_datetime]

config :premiere_ecoute, PremiereEcouteWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: PremiereEcouteWeb.ErrorHTML, json: PremiereEcouteWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: PremiereEcoute.PubSub,
  live_view: [signing_salt: "6RkVNFmy"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :premiere_ecoute, PremiereEcoute.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  premiere_ecoute: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.0.9",
  premiere_ecoute: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :ueberauth, Ueberauth,
  providers: [
    twitch: {Ueberauth.Strategy.Twitch, []}
  ]

import_config "#{config_env()}.exs"
