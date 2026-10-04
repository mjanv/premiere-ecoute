# Secrets and configuration

Set under GitHub → Settings → Secrets and variables → Actions. CI rebuilds `.env.production` from them. Names only here; never write values.

| Group | Secrets |
|---|---|
| SSH | `DO_SSH_PRIVATE_KEY` (passwordless login as root) |
| Phoenix | `PHX_HOST`, `SECRET_KEY_BASE` (`mix phx.gen.secret`) |
| Database | `POSTGRES_DATABASE`, `POSTGRES_USERNAME`, `POSTGRES_PASSWORD`, `POSTGRES_ENCRYPTION_KEY` (`mix guardian.gen.secret \| base64`) |
| Spotify | `SPOTIFY_CLIENT_ID`, `SPOTIFY_CLIENT_SECRET`, `SPOTIFY_REDIRECT_URI` |
| Twitch | `TWITCH_CLIENT_ID`, `TWITCH_CLIENT_SECRET`, `TWITCH_REDIRECT_URI`, `TWITCH_WEBHOOK_CALLBACK_URL`, `TWITCH_EXTENSION_SECRET` |
| Other APIs | `DISCORD_BOT_TOKEN`, `BUYMEACOFFEE_API_KEY`, `RESEND_API_KEY`, `OPENAI_API_KEY`, `MISTRAL_API_KEY`, `SENTRY_DSN` |
| Feature flags admin | `AUTH_USERNAME`, `AUTH_PASSWORD` |

Adding a new env var: add the secret, add it to the workflow's `.env.production` step, add it to `.env.production.example`, and read it in `config/runtime.exs`.

## Changing domain

1. Point the DNS A record at `68.183.219.251`.
2. Update `PHX_HOST` and the three callback secrets: `SPOTIFY_REDIRECT_URI` (`https://<domain>/auth/spotify/callback`), `TWITCH_REDIRECT_URI` (`https://<domain>/auth/twitch/callback`), `TWITCH_WEBHOOK_CALLBACK_URL` (`https://<domain>/webhooks/twitch`).
3. Update the redirect URIs in the Spotify and Twitch developer consoles.
4. Deploy. Traefik obtains the certificate on first HTTPS access.
