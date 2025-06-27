# Premiere Ecoute - Live Music Rating Platform

## Architecture Overview
- **Event-Driven Design:** Commands → Events → State Changes
- **Hexagonal Architecture:** Core domain isolated from external adapters
- **Real-time Updates:** Phoenix LiveView + PubSub
- **Authentication:** Twitch OAuth for Streamers/Admins only
- **Database:** PostgreSQL (SQLite for dev) with proper Elixir structs

## Implementation Plan

### Phase 1: Core Infrastructure
- [x] Generate Phoenix project with SQLite
- [x] Start development server
- [ ] Create static design mockup for streaming dashboard
- [ ] Set up event-driven architecture (Commands/Events)
- [ ] Define core domain entities (Album, Track, ListeningSession, etc.)
- [ ] Implement hexagonal architecture ports

### Phase 2: External Integrations  
- [ ] Spotify adapter (album/track metadata)
- [ ] Twitch OAuth authentication 
- [ ] Twitch API adapter (polls + chat integration)

### Phase 3: Core Features
- [ ] Album selection and metadata download
- [ ] ListeningSession management (start/stop)
- [ ] Real-time voting system
- [ ] Track progression and vote intervals
- [ ] Grade report generation

### Phase 4: User Interface
- [ ] Streamer dashboard LiveView
- [ ] Modern streaming UI design with dark theme
- [ ] OBS-embeddable report display
- [ ] Real-time vote visualization

### Phase 5: Testing & Polish
- [ ] Unit tests for domain logic
- [ ] Integration tests for adapters
- [ ] Final verification and deployment readiness

## Key Technical Decisions
- Commands: `SelectAlbum`, `StartListening`, `StopListening`, `CastVote`
- Events: `AlbumSelected`, `SessionStarted`, `SessionStopped`, `VoteCast`
- All external API data converted to proper Elixir structs
- PostgreSQL for production, SQLite for development
- Twitch OAuth for authentication (Streamers + Admins only)
