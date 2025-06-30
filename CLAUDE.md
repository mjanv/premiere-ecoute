# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

**Setup and Dependencies:**
- `mix setup` - Install and setup dependencies (calls deps.get, ecto.setup, assets.setup, assets.build)
- `mix deps.get` - Install Elixir dependencies

**Running the Application:**
- `mix phx.server` - Start Phoenix server (available at http://localhost:4000)
- `iex -S mix phx.server` - Start Phoenix server in interactive Elixir shell

**Database:**
- `mix ecto.setup` - Create database, run migrations, and seed data
- `mix ecto.reset` - Drop and recreate database
- `mix ecto.create` - Create database
- `mix ecto.migrate` - Run database migrations

**Code Quality:**
- `mix quality` - Run all quality checks (compile with warnings-as-errors, format check, credo strict, dialyzer)
- `mix format` - Format code
- `mix format --check-formatted` - Check if code is formatted
- `mix credo --strict` - Static code analysis
- `mix dialyzer --format short` - Type checking with Dialyzer

**Testing:**
- `mix test` - Run all tests (automatically creates test database and runs migrations)

**Assets:**
- `mix assets.build` - Build assets (Tailwind CSS and esbuild)
- `mix assets.deploy` - Build and minify assets for production

## Architecture Overview

**Core Application Structure:**
- Phoenix web application with LiveView for real-time UI
- Event-driven architecture using a custom Command Bus pattern
- Integration with Spotify and Twitch APIs for music streaming and chat interaction
- User authentication with OAuth2 (Spotify/Twitch)
- SQLite database with Ecto ORM

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

4. **Supervision Tree:**
   - `PremiereEcoute.Application` - Main application supervisor
   - `PremiereEcoute.Supervisor` - Core business logic supervision
   - `PremiereEcoute.Core.Supervisor` - Command bus and event handling
   - `PremiereEcoute.Apis.Supervisor` - External API client supervision

**Error Logging:**
Use the standard Elixir Logger with appropriate levels:
- `Logger.error("error message")` - For errors that need attention
- `Logger.warn("warning message")` - For warnings
- `Logger.info("info message")` - For general information
- `Logger.debug("debug message")` - For debugging (used extensively in command bus)

Always `require Logger` at the top of modules that use logging.

**Testing:**
- Uses ExUnit with Mox for mocking external APIs
- Database isolation with Ecto.Adapters.SQL.Sandbox
- API fixtures and test data in `test/support/`
- Comprehensive test coverage for APIs, core logic, and controllers