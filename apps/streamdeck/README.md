# Stream Deck Plugin — Première Écoute

Controls a Première Écoute listening session from a Stream Deck.

## Actions

| Action | Description |
|---|---|
| **Session Status** | Displays the current session source, refreshed every 5 seconds |
| **Start Session** | Starts the session and skips to the first track |
| **Stop Session** | Stops the current session |
| **Next Track** | Skips to the next track |
| **Previous Track** | Goes back to the previous track |

## Setup

### Prerequisites

- Stream Deck software installed on Windows
- Node.js 20+
- A running Première Écoute instance
- An API token (see below)

### Generate an API token

Stop the server, then run:

```bash
mix run --eval '
user = PremiereEcoute.Repo.get_by!(PremiereEcoute.Accounts.User, username: "YOUR_USERNAME")
token = PremiereEcoute.Accounts.generate_user_api_token(user)
IO.puts(token)
'
```

### Configure the plugin

Click any action in the Stream Deck property inspector and fill in:

- **Server URL** — e.g. `https://premiere-ecoute.fr` (defaults to `http://localhost:4000`)
- **API Token** — the token generated above

Settings are global and shared across all actions.

## Development

This plugin is developed from WSL. The build output is rsynced directly to the Windows Stream Deck plugins directory.

```bash
npm run build    # one-off build
npm run deploy   # build + rsync + restart Stream Deck
npm run watch    # rebuild and redeploy on every file change
```

### Project structure

```
src/
  actions/
    session-status.ts     # polls GET /api/session every 5s
    session-start.ts      # POST /api/session/start
    session-stop.ts       # POST /api/session/stop
    session-next.ts       # POST /api/session/next
    session-previous.ts   # POST /api/session/previous
  api-client.ts           # fetch wrapper, reads global settings
  plugin.ts               # entry point, registers all actions
com.maxime-janvier.premiere-ecoute.sdPlugin/
  manifest.json
  ui/global-settings.html # property inspector (server URL + API token)
  imgs/
  bin/                    # compiled output (git-ignored)
```
