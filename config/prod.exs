import Config

config :premiere_ecoute,
  sentry: "https://maxime-janvier.sentry.io/insights/projects/premiere-ecoute/?project=4509617392975872",
  grafana: "https://mjanv.grafana.net/dashboards/f/B412468D664E3FDF89E566662E1950E3/?orgId=1"

config :premiere_ecoute, PremiereEcoute.Repo,
  ssl: false,
  pool_size: 2

config :premiere_ecoute, PremiereEcoute.Events.Store,
  ssl: false,
  pool_size: 2

config :premiere_ecoute, PremiereEcouteWeb.Endpoint, cache_static_manifest: "priv/static/cache_manifest.json"

config :phoenix_storybook, enabled: false

config :logger, level: :info
