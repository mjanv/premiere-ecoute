import Config

config :premiere_ecoute,
  environment: config_env(),
  ecto_repos: [PremiereEcoute.Repo],
  event_stores: [PremiereEcoute.Events.Store],
  generators: [timestamp_type: :utc_datetime],
  handlers: [
    PremiereEcoute.Sessions.ListeningSession.CommandHandler,
    PremiereEcoute.Sessions.ListeningSession.EventHandler,
    PremiereEcoute.Sessions.Scores.CommandHandler,
    PremiereEcoute.Sessions.Scores.PollHandler
  ],
  twitch_eventsub_secret: "094545d3d0d963dc017d44e66c075d7e11dbee8fc9209885b20fd5b5f2d3772f"

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

config :premiere_ecoute, PremiereEcoute.Accounts,
  bot: "maxime.janvier+premiereecoute@gmail.com",
  admins: ["lanfeust313"],
  bots: ["premiereecoutebot"],
  streamers: ["bebealc8"]

config :premiere_ecoute, PremiereEcoute.Apis,
  twitch: [
    api: PremiereEcoute.Apis.TwitchApi,
    urls: [
      api: "https://api.twitch.tv/helix",
      accounts: "https://id.twitch.tv/oauth2"
    ]
  ],
  spotify: [
    api: PremiereEcoute.Apis.SpotifyApi,
    urls: [
      api: "https://api.spotify.com/v1",
      accounts: "https://accounts.spotify.com/api"
    ]
  ],
  deezer: [
    api: PremiereEcoute.Apis.DeezerApi,
    urls: [
      api: "https://api.deezer.com/"
    ]
  ],
  tidal: [
    api: PremiereEcoute.Apis.TidalApi,
    urls: [
      api: "https://openapi.tidal.com/v2",
      accounts: "https://auth.tidal.com/v1"
    ]
  ],
  frankfurter: [
    api: PremiereEcoute.Apis.FrankfurterApi,
    urls: [
      api: "https://api.frankfurter.app"
    ]
  ],
  discord: [
    api: PremiereEcoute.Apis.DiscordApi,
    urls: [
      api: "https://discord.com/api/v10"
    ],
    channels: [
      notifications: "your_channel_id_here",
      announcements: "your_channel_id_here"
    ]
  ],
  buymeacoffee: [
    api: PremiereEcoute.Apis.BuyMeACoffeeApi,
    urls: [
      api: "https://developers.buymeacoffee.com"
    ]
  ]

config :premiere_ecoute, PremiereEcoute.Sessions, vote_cooldown: 30

config :premiere_ecoute, PremiereEcoute.Festivals, model: PremiereEcoute.Festivals.Models.Static

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

config :premiere_ecoute, PremiereEcoute.Events.Store,
  column_data_type: "jsonb",
  serializer: EventStore.JsonbSerializer,
  types: EventStore.PostgresTypes

config :premiere_ecoute, Oban,
  prefix: "oban",
  repo: PremiereEcoute.Repo,
  engine: Oban.Engines.Basic,
  notifier: Oban.Notifiers.Postgres,
  queues: [
    sessions: 1,
    twitch: 1
    # spotify: 1
  ],
  plugins: [
    {Oban.Plugins.Lifeline, rescue_after: :timer.minutes(5)},
    {Oban.Plugins.Pruner, max_age: _5_minutes = 300},
    Oban.Plugins.Reindexer,
    {Oban.Plugins.Cron,
     crontab: [
       {"@reboot", PremiereEcoute.Apis.Workers.RenewTwitchTokens},
       {"@reboot", PremiereEcoute.Apis.Workers.RenewSpotifyTokens},
       {"@reboot", PremiereEcoute.Apis.Workers.SubscribeStreamEvents}
     ]}
  ]

config :premiere_ecoute, PremiereEcoute.Telemetry.PromEx,
  disabled: false,
  manual_metrics_start_delay: :no_delay,
  drop_metrics_groups: [],
  grafana: :disabled,
  metrics_server: :disabled

config :premiere_ecoute, PremiereEcoute.Gettext,
  locales: ~w(en fr it),
  default_locale: "en"

config :premiere_ecoute, PremiereEcoute.Mailer, adapter: Resend.Swoosh.Adapter

config :esbuild,
  version: "0.17.11",
  premiere_ecoute: [
    args:
      ~w(js/app.js js/storybook.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  version: "4.0.9",
  premiere_ecoute: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
      --config=assets/tailwind.config.js
    ),
    cd: Path.expand("..", __DIR__)
  ],
  storybook: [
    args: ~w(
      --input=css/storybook.css
      --output=../priv/static/assets/storybook.css
      --config=assets/tailwind.config.js
    ),
    cd: Path.expand("../assets", __DIR__)
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

config :instructor,
  adapter: Instructor.Adapters.OpenAI

config :ueberauth, Ueberauth,
  providers: [
    twitch:
      {Ueberauth.Strategy.Twitch,
       [
         default_scope:
           "user:read:email user:read:chat user:write:chat user:bot channel:manage:polls channel:read:polls channel:bot moderator:manage:announcement"
       ]},
    spotify:
      {Ueberauth.Strategy.Spotify,
       [
         default_scope:
           "user-read-private user-read-email user-read-playback-state user-modify-playback-state user-read-currently-playing playlist-read-private playlist-read-collaborative playlist-modify-public playlist-modify-private"
       ]}
  ]

config :swoosh, :api_client, Swoosh.ApiClient.Req

config :tesla, disable_deprecated_builder_warning: true

config :fun_with_flags, :cache_bust_notifications, enabled: false

config :fun_with_flags, :persistence,
  adapter: FunWithFlags.Store.Persistent.Ecto,
  repo: PremiereEcoute.Repo,
  ecto_table_name: "feature_flags",
  ecto_primary_key_type: :id

import_config "#{config_env()}.exs"
