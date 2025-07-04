import Config

config :premiere_ecoute, PremiereEcoute.Repo,
  database: "premiere_ecoute_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :premiere_ecoute, PremiereEcouteWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "QWnUlPd8dtgcO9GqNwZby5dC48OsqV2+qVZpCjhQOh9Hk+t+1pv3pmsgnZ6egjs5",
  server: false

config :premiere_ecoute,
  twitch_req_options: [plug: {Req.Test, PremiereEcoute.Apis.TwitchApi}]

config :bcrypt_elixir, :log_rounds, 1

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  enable_expensive_runtime_checks: true
