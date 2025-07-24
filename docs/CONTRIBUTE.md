# Contributing

## 🚀 Quick Start

### Prerequisites

- [asdf](https://asdf-vm.com/) installed
- [Spotify Developer Account](https://developer.spotify.com/) (for API access)
- [Twitch Developer Account](https://dev.twitch.tv/) (for chat integration)
- PostgreSQL (production) or SQLite (development)

### Setup

```bash
git clone https://github.com/mjanvier/premiere_ecoute.git
cd premiere_ecoute

asdf install
mix setup
cp .env.example .env

mix # Run the server
```

Visit [http://localhost:4000](http://localhost:4000) to access the application.

### Available Commands

```bash
# Development
mix setup                   # Install and setup dependencies
mix phx.server              # Start Phoenix server
mix test                    # Run test suite

# Code Quality
mix format                 # Format code
mix credo --strict         # Static code analysis
mix dialyzer               # Type checking
mix quality                # Run all quality checks

# Database
mix ecto.setup             # Create database and run migrations
mix ecto.reset             # Drop and recreate database
mix ecto.migrate           # Run database migrations

# Deployment
fly deploy
```

## 📁 Project Structure

```
lib/
├── premiere_ecoute/           # Core business logic
│   ├── apis/                  # External API integrations
│   ├── core/                  # Command/Event Bus
│   ├── sessions/              # Session management
│   ├── accounts/              # User authentication
│   └── telemetry/             # Observability
├── premiere_ecoute_web/       # Web interface
│   ├── controllers/           # HTTP controllers
│   ├── live/                  # LiveView modules
│   └── components/            # UI components
├── premiere_ecoute_web.ex     # Web interface entry point
└── premiere_ecoute.ex         # Backend interface entry point
```

Test folder structure follows as close as possible the structure and filenames of `lib/`.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Run quality checks (`mix quality`)
4. Commit your changes (`git commit -am 'Add amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request