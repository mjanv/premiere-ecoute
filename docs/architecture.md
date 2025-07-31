# 🏗️ Architecture overview

**Core Application Structure:**

- Phoenix web application with LiveView for real-time UI
- Event-driven architecture using a custom Command Bus pattern
- Integration with Spotify and Twitch APIs for music streaming and chat interaction
- User authentication with OAuth2 (Spotify/Twitch)

**Key Architectural Components:**

1. **Command Bus Pattern** (`lib/premiere_ecoute/core/command_bus.ex`):
   - Central command processing with validation, handling, and event dispatch
   - Registry-based handler lookup system
   - Structured error handling and event propagation

2. **API Integration Layer** (`lib/premiere_ecoute/apis/`):
   - Spotify API for music search, albums, player control
   - Twitch API for authentication, polls, and EventSub websocket integration
   - Modular API clients with separate concerns (accounts, player, search, etc.)

3. **Session Management** (`lib/premiere_ecoute/sessions/`):
   - Listening sessions with album tracking
   - User voting and scoring system
   - Event-sourced session state management

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