# Frontend Component Architecture Review

## Executive Summary

This comprehensive review analyzes 45+ Phoenix LiveView templates across the Premiere Ecoute application to identify opportunities for component extraction and creation. The analysis reveals significant potential for reducing code duplication through domain-specific components, particularly around Track, Playlist, Album, and Provider elements.

## Current Component Ecosystem

### Existing Components ✅
- `StatusBadge` - Session status indicators with multiple variants
- `Card` - Basic container component with variant support
- `AlbumDisplay` - Album cover and metadata display
- `StatsCard` - Metric display component
- `EmptyState` - Consistent empty state messaging
- `LoadingState` - Loading indicators
- `SpotifyPlayer` - LiveComponent for Spotify integration
- `CoreComponents` - Base Phoenix components

### Design System Maturity
The application demonstrates a well-established design system with:
- Consistent Tailwind CSS usage
- Synthwave/cyberpunk aesthetic
- Color palette with purple/green/amber accents
- Typography hierarchy
- Spacing and layout patterns

## Component Extraction Opportunities

### 1. Domain-Specific Components (HIGH PRIORITY)

#### Track Components
**Current Duplication:** Track rows appear in 5+ templates with similar structure

**Proposed Components:**

##### `TrackRow`
```elixir
# Found in: session_live.html.heex, playlist_live.html.heex
# Repeated pattern: index/play icon + title + artist + duration + actions
<.track_row 
  track={track} 
  index={1} 
  is_current={false}
  show_votes={true}
  show_scores={true}
  selected={false}
  on_select={JS.push("select_track")} 
/>
```

**Benefits:** 
- Eliminates 200+ lines of duplicated code
- Consistent track display across sessions and playlists
- Centralized interaction handling

##### `TrackList`
```elixir
# Container component for track collections
<.track_list 
  tracks={@tracks} 
  show_header={true}
  show_selection={false}
  current_track={@current_track}
/>
```

##### `TrackHistogram`
```elixir
# Found in: session_live.html.heex (voting visualization)
<.track_histogram 
  track_id={track.id} 
  vote_distribution={@vote_distribution}
  vote_options={@vote_options}
/>
```

#### Album/Playlist Components
**Current Duplication:** Album cards in library views, session displays

**Proposed Components:**

##### `AlbumCard`
```elixir
# Found in: library_live.html.heex, home_live.html.heex
<.album_card 
  album={@album}
  size="large"
  show_artist={true}
  clickable={true}
  navigate={~p"/albums/#{@album.id}"}
/>
```

##### `PlaylistCard` 
```elixir
# Found in: library_live.html.heex (grid layout)
<.playlist_card 
  playlist={@playlist}
  show_provider_badge={true}
  show_privacy_badge={true}
  aspect_ratio="square"
/>
```

##### `AlbumDetails`
```elixir
# Found in: session_live.html.heex (compact album info)
<.album_details 
  album={@album}
  layout="compact"
  show_tracks_count={true}
  show_duration={true}
/>
```

#### Provider Components
**Current Duplication:** Spotify/platform integration elements in 8+ templates

##### `ProviderBadge`
```elixir
# Found throughout templates
<.provider_badge provider={:spotify} size="sm" />
<.provider_badge provider={:deezer} size="md" />
```

##### `ProviderButton`
```elixir
# "Open in Spotify" style buttons
<.provider_button 
  provider={:spotify}
  url={@playlist.external_url}
  variant="primary"
>
  Open in Spotify
</.provider_button>
```

### 2. Interactive UI Components (MEDIUM PRIORITY)

#### Form Controls
**Current Duplication:** Custom styled form elements across 10+ templates

##### `FilterButtonGroup`
```elixir
# Found in: playlist_live.html.heex (date filters)
<.filter_button_group 
  options={[
    {"all", "All"},
    {"week", "< 1 week"},
    {"month", "< 1 month"},
    {"year", "< 1 year"}
  ]}
  active={@date_filter}
  on_change={JS.push("filter_by_date")}
/>
```

##### `ToggleSwitch`
```elixir
# Found in: session_live.html.heex (display toggles)
<.toggle_switch 
  checked={@show_votes}
  label="Display votes"
  on_toggle={JS.push("toggle", value: %{flag: "votes"})}
/>
```

##### `SelectionCheckbox`
```elixir
# Found in: playlist_live.html.heex (custom green checkboxes)
<.selection_checkbox 
  checked={@selected}
  on_change={JS.push("toggle_selection")}
  variant="green"
/>
```

##### `RatingButtonGroup`
```elixir
# Found in: session_live.html.heex (voting buttons)
<.rating_button_group 
  options={1..10}
  selected={@user_rating}
  on_rate={JS.push("vote_track")}
  disabled={!@can_vote}
/>
```

#### Action Components

##### `ActionButton`
```elixir
# Standardize button variants across app
<.action_button variant="primary" size="lg" icon="hero-play">
  Start Session
</.action_button>
```

##### `BulkActionBar`
```elixir
# Found in: playlist_live.html.heex
<.bulk_action_bar 
  selected_count={MapSet.size(@selected_tracks)}
  on_clear={JS.push("clear_selection")}
  actions={[
    %{label: "Remove", event: "delete_selected", variant: "danger"}
  ]}
/>
```

### 3. Layout & Container Components (LOW PRIORITY)

#### Card Variations

##### `ActivityCard`
```elixir
# Found in: home_live.html.heex (session/billboard cards)
<.activity_card 
  type="session"
  status={:active}
  title={@session.album.name}
  subtitle={@session.album.artist}
  cover_url={@session.album.cover_url}
  action_text="Continue session"
  navigate={~p"/sessions/#{@session.id}"}
/>
```

##### `FeatureCard`
```elixir
# "Create Session" / "Create Billboard" cards
<.feature_card 
  title="Start Listening Session"
  description="Share music with your community"
  icon="hero-plus"
  navigate={~p"/sessions/new"}
  variant="primary"
/>
```

##### `StatsPanel`
```elixir
# Found in: session_live.html.heex (vote/score displays)
<.stats_panel 
  stats={[
    %{label: "Total Votes", value: @total_votes},
    %{label: "Unique Voters", value: @unique_voters}
  ]}
  variant="compact"
/>
```

#### Navigation Components

##### `SearchFilterBar`
```elixir
# Found in: playlist_live.html.heex
<.search_filter_bar 
  search_query={@search_query}
  filters={@filters}
  on_search={JS.push("search")}
  on_filter_change={JS.push("filter")}
  on_clear={JS.push("clear_filters")}
/>
```

