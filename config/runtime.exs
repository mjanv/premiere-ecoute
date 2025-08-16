import Config
import Dotenvy

source!([
  Path.absname(".env", "."),
  Path.absname(".#{config_env()}.env", "."),
  System.get_env()
])

config :premiere_ecoute, PremiereEcouteWeb.Endpoint, server: env!("PHX_SERVER", :boolean, false)

config :premiere_ecoute,
  spotify_client_id: env!("SPOTIFY_CLIENT_ID"),
  spotify_client_secret: env!("SPOTIFY_CLIENT_SECRET"),
  spotify_redirect_uri: env!("SPOTIFY_REDIRECT_URI")

config :premiere_ecoute,
  twitch_client_id: env!("TWITCH_CLIENT_ID"),
  twitch_client_secret: env!("TWITCH_CLIENT_SECRET"),
  twitch_redirect_uri: env!("TWITCH_REDIRECT_URI"),
  twitch_webhook_callback_url: env!("TWITCH_WEBHOOK_CALLBACK_URL"),
  twitch_eventsub_secret: env!("TWITCH_WEBHOOK_SECRET")

config :premiere_ecoute, :feature_flags,
  username: env!("AUTH_USERNAME"),
  password: env!("AUTH_PASSWORD")

config :premiere_ecoute, PremiereEcoute.Repo,
  schema: "public",
  database: env!("POSTGRES_DATABASE", :string, "premiere_ecoute_#{config_env()}"),
  username: env!("POSTGRES_USERNAME"),
  password: env!("POSTGRES_PASSWORD"),
  hostname: env!("POSTGRES_HOSTNAME"),
  socket_options: if(env!("ECTO_IPV6", :string, nil) in ~w(true 1), do: [:inet6], else: [])

config :premiere_ecoute, PremiereEcoute.Events.Store,
  schema: "event_store",
  database: env!("POSTGRES_DATABASE", :string, "premiere_ecoute_#{config_env()}"),
  username: env!("POSTGRES_USERNAME"),
  password: env!("POSTGRES_PASSWORD"),
  hostname: env!("POSTGRES_HOSTNAME"),
  socket_options: if(env!("ECTO_IPV6", :string, nil) in ~w(true 1), do: [:inet6], else: [])

config :premiere_ecoute, PremiereEcoute.Repo.Vault,
  ciphers: [
    default: {
      Cloak.Ciphers.AES.GCM,
      tag: "AES.GCM.V1", key: 32 |> :crypto.strong_rand_bytes(), iv_length: 12
    }
  ]

config :premiere_ecoute, PremiereEcoute.Mailer, api_key: env!("RESEND_API_KEY")

config :ueberauth, Ueberauth.Strategy.Twitch.OAuth,
  client_id: env!("TWITCH_CLIENT_ID"),
  client_secret: env!("TWITCH_CLIENT_SECRET")

config :ueberauth, Ueberauth.Strategy.Spotify.OAuth,
  client_id: env!("SPOTIFY_CLIENT_ID"),
  client_secret: env!("SPOTIFY_CLIENT_SECRET")

config :sentry, dsn: env!("SENTRY_DSN")

if config_env() == :prod do
  config :premiere_ecoute, :dns_cluster_query, env!("DNS_CLUSTER_QUERY")

  config :premiere_ecoute, PremiereEcouteWeb.Endpoint,
    url: [host: env!("PHX_HOST"), port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: env!("PORT", :integer, 4000)
    ],
    secret_key_base: env!("SECRET_KEY_BASE")

  config :premiere_ecoute, PremiereEcoute.Telemetry.PromEx,
    manual_metrics_start_delay: :no_delay,
    grafana: :disabled
end
