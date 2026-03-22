# Stream Deck Plugin — Première Écoute

Controls a Première Écoute listening session from a Stream Deck. Two plugins are available: one for streamers, one for viewers.

## Plugins

### Streamer (`com.maxime-janvier.premiere-ecoute-streamer`)

Full session control.

| Action | Description |
|---|---|
| **Session Status** | Displays the current session source, refreshed every 5 seconds |
| **Start Session** | Starts the session and skips to the first track |
| **Stop Session** | Stops the current session |
| **Next Track** | Skips to the next track |
| **Previous Track** | Goes back to the previous track |
| **Vote / Vote Up / Vote Down** | Submit a rating for the current track |

### Viewer (`com.maxime-janvier.premiere-ecoute-viewer`)

Vote-only access, targeting a streamer's session.

| Action | Description |
|---|---|
| **Vote / Vote Up / Vote Down** | Submit a rating for the current track |

## Installation

Download the latest `.streamDeckPlugin` files from the [GitHub releases](https://github.com/mjanv/premiere-ecoute/releases) and double-click to install.

## Setup

### Prerequisites

- Stream Deck software installed on Windows or macOS
- A running Première Écoute instance
- An API token

### Configure the plugin

Click any action in the Stream Deck property inspector and fill in:

**Streamer plugin:**
- **Server URL** — e.g. `https://premiere-ecoute.fr` (defaults to `http://localhost:4000`)
- **API Token** — the token generated above

**Viewer plugin:**
- **Server URL** — e.g. `https://premiere-ecoute.fr`
- **API Token** — the token generated above
- **Broadcaster Username** — the Première Écoute username of the streamer to vote for

Settings are global and shared across all actions.

## Development

This plugin is developed from WSL. The build output is rsynced directly to the Windows Stream Deck plugins directory.

```bash
npm run build    # one-off build
npm run release  # build + package both plugins as .streamDeckPlugin files
npm run deploy   # build + rsync + restart Stream Deck (streamer only)
npm run watch    # rebuild and redeploy on every file change
```

