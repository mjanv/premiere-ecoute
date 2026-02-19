import Config

config :premiere_ecoute,
  twitch_eventsub_secret: "s3cre77890ab",
  tidal_client_id: "test_tidal_client_id",
  tidal_client_secret: "test_tidal_client_secret",
  buymeacoffee_api_key: "test_buymeacoffee_api_key"

config :premiere_ecoute, Oban, testing: :inline

config :premiere_ecoute,
  handlers: [
    PremiereEcoute.Sessions.ListeningSession.CommandHandler,
    PremiereEcoute.Sessions.ListeningSession.EventHandler,
    PremiereEcoute.Sessions.Scores.CommandHandler,
    PremiereEcoute.Sessions.Scores.PollHandler,
    PremiereEcouteCore.CommandBusTest.Handler,
    PremiereEcouteCore.CommandBusTest.EventDispatcher,
    PremiereEcouteCore.EventBusTest.Handler
  ]

config :premiere_ecoute, PremiereEcoute.Apis,
  twitch: [
    api: PremiereEcoute.Apis.Streaming.TwitchApi.Mock,
    req_options: [plug: {Req.Test, PremiereEcoute.Apis.Streaming.TwitchApi}]
  ],
  spotify: [
    api: PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock,
    req_options: [plug: {Req.Test, PremiereEcoute.Apis.MusicProvider.SpotifyApi}]
  ],
  deezer: [
    api: PremiereEcoute.Apis.MusicProvider.DeezerApi,
    req_options: [plug: {Req.Test, PremiereEcoute.Apis.MusicProvider.DeezerApi}]
  ],
  tidal: [
    api: PremiereEcoute.Apis.MusicProvider.TidalApi,
    req_options: [plug: {Req.Test, PremiereEcoute.Apis.MusicProvider.TidalApi}]
  ],
  frankfurter: [
    api: PremiereEcoute.Apis.Payments.FrankfurterApi,
    req_options: [plug: {Req.Test, PremiereEcoute.Apis.Payments.FrankfurterApi}]
  ],
  discord: [
    api: PremiereEcoute.Apis.DiscordApi,
    req_options: [plug: {Req.Test, PremiereEcoute.Apis.DiscordApi}]
  ],
  buymeacoffee: [
    api: PremiereEcoute.Apis.Payments.BuyMeACoffeeApi,
    req_options: [plug: {Req.Test, PremiereEcoute.Apis.Payments.BuyMeACoffeeApi}]
  ]

config :premiere_ecoute, PremiereEcoute.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :premiere_ecoute, PremiereEcoute.Events.Store,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :premiere_ecoute, PremiereEcouteWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "QWnUlPd8dtgcO9GqNwZby5dC48OsqV2+qVZpCjhQOh9Hk+t+1pv3pmsgnZ6egjs5",
  server: false

config :premiere_ecoute, PremiereEcoute.Gettext, default_locale: "en"

config :premiere_ecoute, PremiereEcoute.Accounts.Mailer, adapter: Swoosh.Adapters.Test

config :bcrypt_elixir, :log_rounds, 1

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  enable_expensive_runtime_checks: true
