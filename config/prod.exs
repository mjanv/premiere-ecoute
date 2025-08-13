import Config

config :premiere_ecoute,
  sentry: "https://maxime-janvier.sentry.io/insights/projects/premiere-ecoute/?project=4509617392975872",
  grafana: "https://fly-metrics.net/d/fly-app/fly-app?orgId=140881"

config :premiere_ecoute, PremiereEcoute.Repo,
  ssl: true,
  pool_size: 5

config :premiere_ecoute, PremiereEcoute.Events.Store,
  ssl: true,
  pool_size: 5

config :premiere_ecoute, PremiereEcouteWeb.Endpoint, cache_static_manifest: "priv/static/cache_manifest.json"

config :phoenix_storybook, enabled: false

config :logger, level: :info
