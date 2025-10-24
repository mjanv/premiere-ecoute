import Config

config :premiere_ecoute,
  twitch_eventsub_secret: "s3cre77890ab",
  twitch_extension_secret: Base.encode64("test_secret_key_for_twitch_extension"),
  twitch_client_id: "test_twitch_client_id",
  twitch_client_secret: "test_twitch_client_secret",
  twitch_redirect_uri: "http://localhost:4000/auth/twitch/callback",
  tidal_client_id: "test_tidal_client_id",
  tidal_client_secret: "test_tidal_client_secret",
  discord_bot_token: "test_bot_token"

# AIDEV-NOTE: Fake OpenAI API key for unit tests
config :instructor,
  openai: [api_key: "sk-test-fake-openai-key-for-unit-tests"]

config :premiere_ecoute, Oban, testing: :inline

config :premiere_ecoute,
  handlers: [
    PremiereEcoute.Sessions.ListeningSession.CommandHandler,
    PremiereEcoute.Sessions.ListeningSession.EventHandler,
    PremiereEcoute.Sessions.Scores.PollHandler,
    PremiereEcouteCore.CommandBusTest.Handler,
    PremiereEcouteCore.CommandBusTest.EventDispatcher,
    PremiereEcouteCore.EventBusTest.Handler
  ]

config :premiere_ecoute, PremiereEcoute.Apis,
  twitch: [
    api: PremiereEcoute.Apis.TwitchApi.Mock,
    req_options: [plug: {Req.Test, PremiereEcoute.Apis.TwitchApi}]
  ],
  spotify: [
    api: PremiereEcoute.Apis.SpotifyApi.Mock,
    req_options: [plug: {Req.Test, PremiereEcoute.Apis.SpotifyApi}]
  ],
  deezer: [
    api: PremiereEcoute.Apis.DeezerApi,
    req_options: [plug: {Req.Test, PremiereEcoute.Apis.DeezerApi}]
  ],
  tidal: [
    api: PremiereEcoute.Apis.TidalApi,
    req_options: [plug: {Req.Test, PremiereEcoute.Apis.TidalApi}]
  ],
  frankfurter: [
    api: PremiereEcoute.Apis.FrankfurterApi,
    req_options: [plug: {Req.Test, PremiereEcoute.Apis.FrankfurterApi}]
  ],
  discord: [
    api: PremiereEcoute.Apis.DiscordApi,
    req_options: [plug: {Req.Test, PremiereEcoute.Apis.DiscordApi}]
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

config :premiere_ecoute, PremiereEcoute.Mailer, adapter: Swoosh.Adapters.Test

config :bcrypt_elixir, :log_rounds, 1

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  enable_expensive_runtime_checks: true
