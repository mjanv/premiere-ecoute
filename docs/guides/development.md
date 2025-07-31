# Development guide

## 🚀 Quick Start

### Prerequisites

#### Tools

- [asdf](https://asdf-vm.com/) installed
- [Docker Compose](https://docs.docker.com/compose) installed

#### APIs

- [A Spotify developer account](https://developer.spotify.com/) (for API access)
- [A Twitch developer account](https://dev.twitch.tv/) (for chat integration)

To get the required API credentials, you'll need to create applications on both platforms. For Spotify, go to the Spotify Developer Dashboard, create a new app, and grab your Client ID and Client Secret. Make sure to add http://localhost:4000/auth/spotify/callback as a redirect URI in your app settings.

For Twitch, visit the Twitch Developer Console, create a new application, and get your Client ID and Client Secret. Set the OAuth redirect URL to http://localhost:4000/auth/twitch/callback. You'll also need to generate a webhook secret (any random string) for securing webhook communications between Twitch and your application.

Once you have your credentials, update your `.env` file with the actual values:

```
# Spotify API
SPOTIFY_CLIENT_ID=your_spotify_client_id
SPOTIFY_CLIENT_SECRET=your_spotify_client_secret
SPOTIFY_REDIRECT_URI=http://localhost:4000/auth/spotify/callback

# Twitch API
TWITCH_CLIENT_ID=your_twitch_client_id
TWITCH_CLIENT_SECRET=your_twitch_client_secret
TWITCH_REDIRECT_URI=http://localhost:4000/auth/twitch/callback
TWITCH_WEBHOOK_CALLBACK_URL=http://localhost:4000/webhooks/twitch
TWITCH_WEBHOOK_SECRET=your_webhook_secret
```

> Note for local development: The application uses different API patterns during development. For Twitch, only OAuth requests go to the real Twitch API - all other requests (chat, webhooks, etc.) are routed to http://localhost:4001 which acts as a mock server, whose code is available at `lib/premiere_ecoute_mock`. For Spotify, both OAuth and Web API requests use the real Spotify services.

### First setup

```bash
git clone https://github.com/mjanvier/premiere_ecoute.git
cd premiere_ecoute
cp .env.example .env

asdf install # Install Erlang and Elixir
docker compose up -d # Start database
mix setup # Install dependencies, deploy assets, and run migrations
mix # Run the server
```

Visit [http://localhost:4000](http://localhost:4000) to access the application.

## 🔁 Application lifecycle

### Code quality

```bash
mix format         # Format code
mix credo --strict # Static code analysis
mix dialyzer       # Type checking
mix quality        # Run all quality checks
```

### Audit

```bash
mix sobelow                            # Detect common security vulnerabilities
mix deps.audit                         # Scan for security vulnerabilities in Mix dependencie
mix hex.outdated --within-requirements # Ensure that all library versions are up to date
mix audit                              # Run all auditing checks
```

### Tests

```bash
mix test # Run unit tests suite
```

### Database

```bash
mix ecto.setup   # Create database and run migrations
mix ecto.reset   # Drop and recreate database
mix ecto.create  # Create database without running migrations
mix ecto.migrate # Run database migrations
```
