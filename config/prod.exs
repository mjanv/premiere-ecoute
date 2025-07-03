import Config

config :premiere_ecoute, PremiereEcoute.Repo,
  database: "premiere_ecoute",
  pool_size: 10

config :premiere_ecoute, PremiereEcouteWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json"

config :logger, level: :info
