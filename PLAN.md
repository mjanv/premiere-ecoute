# Daily Playlist Feature - Architecture Plan

## Feature

“What was this title you streamed today ?”

Whenever a stream is started, a Spotify player instance is spinned up is used to track every track played during a stream by querying the API every minute to retrieve every listened song. Whenever a new song is detected, it is registered in the day playlist of the streamer. The Spotify player goes inactive whenever the stream ends.

The feature can be activated or not by the streamer. A public page is available for viewers to see which tracks have been played on a specific day. Older day playlists can be automatically deleted (1 week after for example).

---

## Summary

Track every song played during a Twitch stream by polling Spotify's playback API every minute. Store tracks in a daily playlist that viewers can browse. The feature is opt-in per streamer with configurable retention policy.

---

## Requirements Analysis

### Core Requirements

1. **Spotify Playback Tracking**: Poll Spotify Player API every 60 seconds during active streams
2. **Daily Playlist Creation**: Automatically create/reuse a daily playlist for the streamer
3. **Track Recording**: Store each detected track in the daily playlist
4. **Stream Lifecycle Integration**: Start tracking when stream goes online, stop when offline
5. **Streamer Settings**: Feature can be enabled/disabled per streamer
6. **Public Viewer Page**: Display tracks played on a specific day
7. **Automatic Cleanup**: Delete old playlists (configurable retention, default: 1 week)

### Non-Functional Requirements

1. **Performance**: Polling every 60 seconds should not impact stream performance
2. **Reliability**: Handle Spotify API failures gracefully (rate limits, token expiration, no active device)
3. **Data Integrity**: Avoid duplicate tracks, handle session interruptions
4. **Privacy**: Respect streamer settings; only public if streamer enables it

---

## Database Schema Changes

### New Table: `stream_tracks`

```sql
create table(:stream_tracks) do
  add :user_id, references(:users, on_delete: :delete_all), null: false

  # Track metadata (denormalized from Spotify API)
  add :provider_id, :string, null: false       # Spotify track ID
  add :name, :string, null: false
  add :artist, :string, null: false
  add :album, :string
  add :duration_ms, :integer

  # Playback detection timestamp
  add :started_at, :utc_datetime, null: false

  timestamps()
end

create index(:stream_tracks, [:user_id, :started_at])
create index(:stream_tracks, [:started_at])
```

**Rationale**:
- **One row per track**: Simple, normalized table structure
- **Completely decoupled**: No foreign keys to `albums`, `playlists`, or any discography tables
- **Only relationship**: `user_id` → `users` table
- **Denormalized track data**: Stores all Spotify metadata directly (independent of library)
- **Natural ordering**: Query by `started_at` for chronological playback order
- **Consecutive prevention**: Application-level check prevents same track appearing twice in a row
- **No date field**: Use `started_at` datetime for date-based queries (more flexible)
- **No Spotify sync fields**: Feature stores tracks locally only

### User Settings Extension

Extend `User.Profile` embed with stream tracking settings:

```elixir
# In lib/premiere_ecoute/accounts/user/profile.ex
embedded_schema do
  # ... existing fields ...

  embeds_one :stream_track_settings, StreamTrackSettings, on_replace: :update do
    field :enabled, :boolean, default: false
    field :retention_days, :integer, default: 7
    field :visibility, Ecto.Enum, values: [:private, :public], default: :public
  end
end
```

**Rationale**: Settings are per-user configuration, not global. Embedding in `Profile` follows existing pattern (`color_scheme`, `language`).

---

## Core Components

### 1. Background Workers (Oban)

#### `TrackSpotifyPlayback` Worker

**Responsibility**: Poll Spotify Player API and insert track rows

```elixir
# lib/premiere_ecoute/stream_tracks/workers/track_spotify_playback.ex

use PremiereEcouteCore.Worker, queue: :spotify, max_attempts: 3

@impl true
def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
  scope = Scope.for_user(Accounts.get_user!(user_id))

  with true <- feature_enabled?(scope),
       {:ok, playback} <- Apis.spotify().get_playback_state(scope, Player.default()),
       {:ok, _track} <- store_track_if_new(scope.user.id, playback),
       :ok <- schedule_next_poll(user_id) do
    :ok
  else
    false ->
      Logger.debug("Stream track tracking disabled for user #{user_id}")
      :ok

    {:error, "Spotify rate limit exceeded"} ->
      __MODULE__.in_seconds(%{user_id: user_id}, 300)
      :ok

    {:error, :consecutive_duplicate} ->
      # Same track still playing, schedule next poll
      schedule_next_poll(user_id)
      :ok

    {:error, reason} ->
      Logger.error("Playback tracking failed: #{inspect(reason)}")
      :ok
  end
end

defp store_track_if_new(user_id, %{"item" => %{"id" => provider_id}} = playback) do
  StreamTracks.insert_track(user_id, %{
    provider_id: provider_id,
    name: get_in(playback, ["item", "name"]),
    artist: get_in(playback, ["item", "artists"]) |> hd() |> Map.get("name"),
    album: get_in(playback, ["item", "album", "name"]),
    duration_ms: get_in(playback, ["item", "duration_ms"]),
    started_at: DateTime.utc_now()
  })
end

defp schedule_next_poll(user_id) do
  __MODULE__.in_seconds(%{user_id: user_id}, 60)
  :ok
end
```

**Key Design Decisions**:
- **Self-scheduling**: Worker schedules next poll on success (follows existing `RenewSpotifyTokens` pattern)
- **One row per track**: Each detected track becomes a new row
- **Consecutive prevention**: Checks last track before inserting to prevent same track twice in a row
- **Allows track repetition**: Same track can appear multiple times per day, just not consecutively
- **Denormalized data**: Stores track metadata from Spotify response
- **Graceful degradation**: Errors don't stop polling, just log and continue
- **Rate limit handling**: 5-minute backoff on rate limits
- **Feature flag check**: Early exit if feature disabled
- **Timestamp-based**: Uses `started_at` for all date/time queries


#### `CleanupOldTracks` Worker

**Responsibility**: Delete stream tracks older than retention policy

```elixir
# lib/premiere_ecoute/stream_tracks/workers/cleanup_old_tracks.ex

use PremiereEcouteCore.Worker, queue: :cleanup, max_attempts: 1

@impl true
def perform(%Oban.Job{}) do
  # Query users with retention settings
  # Delete tracks older than retention_days per user
  Accounts.streamers()
  |> Enum.each(fn user ->
    retention_days = get_in(user.profile.stream_playlist_settings, [:retention_days]) || 7
    cutoff_date = Date.utc_today() |> Date.add(-retention_days)

    # Delete tracks and optionally Spotify playlists
    StreamTracks.delete_tracks_before_date(user.id, cutoff_date)
  end)

  :ok
end
```

**Scheduling**: Run daily via Oban cron (configured in `application.ex`)

**Note**: Optionally delete Spotify playlists (if `spotify_playlist_id` populated), but local tracks are always deleted after retention period.

---

### 2. Context Module: `StreamTracks`

**Responsibility**: Business logic for stream track management

```elixir
# lib/premiere_ecoute/stream_tracks.ex

defmodule PremiereEcoute.StreamTracks do
  @moduledoc """
  Context for managing stream playback tracking.
  Completely decoupled from discography - only related to users.
  """

  import Ecto.Query
  alias PremiereEcoute.StreamTracks.StreamTrack
  alias PremiereEcoute.Repo

  # Insert a new track (duplicate-safe via unique constraint)
  @spec insert_track(integer(), map()) :: {:ok, StreamTrack.t()} | {:error, term()}
  def insert_track(user_id, track_data) do
    %StreamTrack{}
    |> StreamTrack.changeset(Map.put(track_data, :user_id, user_id))
    |> Repo.insert()
    |> case do
      {:ok, track} -> {:ok, track}
      {:error, %{errors: [provider_id: {"has already been taken", _}]}} -> {:error, :duplicate_track}
      {:error, changeset} -> {:error, changeset}
    end
  end

  # Get all tracks for a user on a specific date (ordered by started_at)
  @spec get_tracks(integer(), Date.t()) :: [StreamTrack.t()]
  def get_tracks(user_id, date) do
    start_of_day = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    end_of_day = DateTime.new!(date, ~T[23:59:59], "Etc/UTC")

    from(t in StreamTrack,
      where: t.user_id == ^user_id and t.started_at >= ^start_of_day and t.started_at <= ^end_of_day,
      order_by: [asc: t.started_at]
    )
    |> Repo.all()
  end

  # Delete tracks older than cutoff datetime
  @spec delete_tracks_before(integer(), DateTime.t()) :: {integer(), nil | [term()]}
  def delete_tracks_before(user_id, cutoff_datetime) do
    from(t in StreamTrack,
      where: t.user_id == ^user_id and t.started_at < ^cutoff_datetime
    )
    |> Repo.delete_all()
  end

  # Check if user has public tracks for a date
  @spec has_public_tracks?(User.t(), Date.t()) :: boolean()
  def has_public_tracks?(user, date) do
    visibility = get_in(user.profile.stream_track_settings, [:visibility])
    visibility == :public && get_tracks(user.id, date) != []
  end
end
```

**Key Design Decisions**:
- **One row per track**: Simple, straightforward table operations
- **Duplicate prevention**: Unique constraint on `[:user_id, :provider_id, :started_at]` handles duplicates
- **DateTime-based queries**: Use `started_at` for all temporal queries
- **Date filtering**: Convert date to datetime range for efficient queries
- **Ordered results**: Always order by `started_at` for chronological playback
- **Public API**: Only expose necessary functions to other contexts
- **No complex joins**: All data in one table

---


---

### 4. Twitch Stream Event Integration

**Modify**: `lib/premiere_ecoute_web/controllers/webhooks/twitch_controller.ex`

Update event handlers for `stream.online` and `stream.offline`:

```elixir
# Line 137-149 (stream.online handler)
def handle(%{
      "subscription" => %{"type" => "stream.online"},
      "event" => %{
        "broadcaster_user_id" => broadcaster_id,
        "broadcaster_user_name" => broadcaster_name
      } = event
    }) do
  Logger.info("Stream started: #{broadcaster_name} (ID: #{broadcaster_id})")

  %StreamStarted{
    broadcaster_id: broadcaster_id,
    broadcaster_name: broadcaster_name,
    started_at: event["started_at"]
  }
end

# Line 152-161 (stream.offline handler)
def handle(%{
      "subscription" => %{"type" => "stream.offline"},
      "event" => %{
        "broadcaster_user_id" => broadcaster_id,
        "broadcaster_user_name" => broadcaster_name
      }
    }) do
  Logger.info("Stream ended: #{broadcaster_name} (ID: #{broadcaster_id})")

  %StreamEnded{
    broadcaster_id: broadcaster_id,
    broadcaster_name: broadcaster_name
  }
end
```

**Note**: No changes needed - existing event structure already sufficient

**New Event Definitions**:

```elixir
# lib/premiere_ecoute/events/twitch/stream_started.ex
defmodule PremiereEcoute.Events.Twitch.StreamStarted do
  defstruct [:broadcaster_id, :broadcaster_name, :started_at]
  @type t :: %__MODULE__{...}
end

# lib/premiere_ecoute/events/twitch/stream_ended.ex
defmodule PremiereEcoute.Events.Twitch.StreamEnded do
  defstruct [:broadcaster_id, :broadcaster_name]
  @type t :: %__MODULE__{...}
end
```

**Event Handlers**:

```elixir
# lib/premiere_ecoute/stream_tracks/event_handler.ex

defmodule PremiereEcoute.StreamTracks.EventHandler do
  use GenServer

  alias PremiereEcoute.Events.Twitch.{StreamStarted, StreamEnded}
  alias PremiereEcoute.StreamTracks.Workers.TrackSpotifyPlayback

  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def init(_) do
    Phoenix.PubSub.subscribe(PremiereEcoute.PubSub, "twitch:events")
    {:ok, %{}}
  end

  def handle_info({:stream_event, %StreamStarted{} = event}, state) do
    user = Accounts.get_user_by_twitch_id(event.broadcaster_id)

    if stream_tracking_enabled?(user) do
      # Start polling immediately
      TrackSpotifyPlayback.perform_now(%{user_id: user.id})
    end

    {:noreply, state}
  end

  def handle_info({:stream_event, %StreamEnded{} = _event}, state) do
    # Polling worker will stop on next iteration when stream offline detected
    {:noreply, state}
  end

  defp stream_tracking_enabled?(user) do
    get_in(user.profile.stream_track_settings, [:enabled]) == true
  end
end
```

**Key Design Decisions**:
- **Event-driven**: Stream events trigger polling start/stop via PubSub
- **No setup needed**: Tracks are inserted directly, no parent entity needed
- **Worker coordination**: Polling starts on `stream.online`, stops naturally when stream offline
- **Idempotent**: Multiple `stream.online` events just restart polling

---

### 3. Public Viewer Page (LiveView)

**New LiveView**: `lib/premiere_ecoute_web/live/stream_tracks/viewer_live.ex`

**Route**: `/streamers/:username/tracks/:date`

```elixir
defmodule PremiereEcouteWeb.StreamTracks.ViewerLive do
  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.StreamTracks

  @impl true
  def mount(%{"username" => username, "date" => date_str}, _session, socket) do
    with {:ok, date} <- Date.from_iso8601(date_str),
         user <- Accounts.get_user_by_twitch_username(username),
         true <- tracks_visible?(user),
         tracks <- StreamTracks.get_tracks(user.id, date),
         true <- length(tracks) > 0 do

      Phoenix.PubSub.subscribe(PremiereEcoute.PubSub, "stream_tracks:#{user.id}:#{Date.to_iso8601(date)}")

      {:ok, assign(socket,
        user: user,
        date: date,
        tracks: tracks,
        page_title: "#{username}'s tracks - #{date}"
      )}
    else
      _ -> {:ok, push_navigate(socket, to: "/404")}
    end
  end

  @impl true
  def handle_info({:track_added, track}, socket) do
    {:noreply, update(socket, :tracks, &(&1 ++ [track]))}
  end

  defp tracks_visible?(user) do
    get_in(user.profile.stream_track_settings, [:visibility]) == :public
  end
end
```

**Template**: Display tracks with metadata (started_at, name, artist, album)

**Key Design Decisions**:
- **Real-time updates**: Subscribe to PubSub for live track additions during active streams
- **Privacy enforcement**: Check user settings before allowing access
- **Date navigation**: Allow browsing previous days' tracks
- **Simple rendering**: Query tracks directly, no parent entity needed

---

## Data Flow

### Stream Start Flow

```
Twitch EventSub: stream.online
  ↓
TwitchController.handle/1 → StreamStarted event
  ↓
Phoenix.PubSub.broadcast("twitch:events", {:stream_event, %StreamStarted{}})
  ↓
StreamTracks.EventHandler.handle_info/2
  ├─ Check if feature enabled for user
  └─ TrackSpotifyPlayback.perform_now(%{user_id: user.id})
  ↓
Start polling loop (every 60 seconds)
```

### Playback Polling Loop

```
TrackSpotifyPlayback.perform/1 (runs every 60s)
  ↓
Apis.spotify().get_playback_state/2
  ↓
StreamTracks.insert_track/2
  ├─ user_id: current user
  ├─ track_data: {provider_id, name, artist, album, duration_ms, started_at: DateTime.utc_now()}
  └─ Check last track: Query most recent track for user
  ↓
Last track check
  ├─ If last track.provider_id == current provider_id: {:error, :consecutive_duplicate}
  └─ Otherwise: INSERT INTO stream_tracks (one row)
  ↓
Phoenix.PubSub.broadcast("stream_tracks:#{user_id}:#{date}", {:track_added, track})
  ↓
Schedule next poll (TrackSpotifyPlayback.in_seconds/2)
```

### Stream End Flow

```
Twitch EventSub: stream.offline
  ↓
TwitchController.handle/1 → StreamEnded event
  ↓
Phoenix.PubSub.broadcast("twitch:events", {:stream_event, %StreamEnded{}})
  ↓
StreamTracks.EventHandler.handle_info/2
  └─ Polling worker stops on next iteration (stream offline)
```

---

## Edge Cases & Error Handling

### 1. Spotify API Errors

| Error | Handling Strategy |
|-------|------------------|
| Rate limit (429) | Backoff 5 minutes, log warning |
| No active device (404) | Skip snapshot, continue polling |
| Token expired (401) | Trigger token refresh (existing `RenewSpotifyTokens` worker) |
| Premium required (403) | Log error, disable feature for user |
| Network timeout | Retry 3 times with exponential backoff |

### 2. Consecutive Track Prevention

**Problem**: Same track should not appear twice consecutively, but can appear multiple times throughout the day

**Solution**: Check last inserted track for user before inserting new one

```elixir
def insert_track(user_id, track_data) do
  last_track = get_last_track(user_id)

  case last_track do
    %StreamTrack{provider_id: ^provider_id} when provider_id == track_data.provider_id ->
      {:error, :consecutive_duplicate}

    _ ->
      %StreamTrack{}
      |> StreamTrack.changeset(Map.put(track_data, :user_id, user_id))
      |> Repo.insert()
  end
end

defp get_last_track(user_id) do
  from(t in StreamTrack,
    where: t.user_id == ^user_id,
    order_by: [desc: t.started_at],
    limit: 1
  )
  |> Repo.one()
end
```

**Benefits**:
- Allows same track multiple times per day
- Prevents consecutive duplicates (user pausing/replaying)
- Application-level logic (flexible, easy to modify)
- Simple query for last track check

### 3. Multiple Stream Sessions Per Day

**Problem**: Streamer may start/stop stream multiple times in one day

**Solution**: All tracks are inserted with `started_at` timestamps. Tracks are naturally grouped by user and date range in queries. Consecutive check allows same track to appear multiple times per day, just not twice in a row.


### 4. Clock Skew (Date Boundaries)

**Problem**: Polling near midnight may cross date boundary

**Solution**: Use `DateTime.utc_now()` for `started_at` on each track. Tracks naturally belong to the date/time they were detected. Date-based queries convert date to datetime range.

### 5. Feature Disabled Mid-Stream

**Problem**: Streamer disables feature while stream is active

**Solution**: Worker checks `feature_enabled?/1` on each poll; if disabled, stops scheduling next poll gracefully

---

## Migration Strategy

### Phase 1: Database Setup
1. Add `stream_tracks` table (one row per track)
2. Extend `User.Profile` with `stream_playlist_settings` embed
3. Run migrations

### Phase 2: Core Workers
1. Implement `TrackSpotifyPlayback` worker
2. Implement `SyncDailyPlaylist` worker
3. Add Oban queue configuration

### Phase 3: Event Integration
1. Add `StreamStarted` and `StreamEnded` events
2. Modify `TwitchController` to emit events
3. Implement `DailyPlaylists.EventHandler` GenServer
4. Add to supervision tree

### Phase 4: Service Layer
1. Implement `StreamTracks` context module with simple row operations

### Phase 5: Public Interface
1. Implement `ViewerLive` LiveView
2. Add route and navigation
3. Add PubSub real-time updates

### Phase 6: Cleanup & Monitoring
1. Implement `CleanupOldPlaylists` worker
2. Add Oban cron schedule
3. Add Prometheus metrics (playlist creation, sync failures, poll latency)


---

## Open Questions

1. **Duplicate detection window**: Should we prevent adding the same track if it was just added in the last N minutes (e.g., user skips back)?
   - **Recommendation**: No, keep it simple. If Spotify says it's playing, record it.

2. **Playlist ordering**: Should tracks be ordered by `detected_at` or by `progress_ms`?
   - **Recommendation**: Order by `detected_at` (insertion order). Spotify playlists don't support timestamp metadata.

3. **Private mode**: If streamer sets playlist to private, should we still track snapshots?
   - **Recommendation**: Yes, track snapshots but don't create public LibraryPlaylist. Allow streamer to change visibility later.

4. **Backfill support**: If streamer enables feature mid-stream, should we backfill from Spotify recently played?
   - **Recommendation**: No for MVP. Too complex, recently played API has different data structure.

---

## Conclusion

This architecture balances simplicity with robustness. By using a **single table design with one row per track**, the feature is completely isolated from existing discography tables and only related to users. This approach provides:

- **Simplicity**: One table, standard relational schema
- **Complete decoupling**: No foreign keys to `albums`, `playlists`, or any discography tables
- **Local-only storage**: Tracks exist only in local database, no Spotify playlist sync
- **Denormalized data**: All Spotify metadata stored directly in track rows
- **Efficient queries**: Standard PostgreSQL indexes on `[:user_id, :started_at]`
- **Duplicate prevention**: Unique constraint at database level using timestamp
- **Natural grouping**: Tracks grouped by user and datetime range in queries

By reusing existing patterns (workers, events, PubSub), the feature integrates seamlessly into the codebase. The polling approach is straightforward and reliable, while the event-driven stream lifecycle ensures tracking starts/stops automatically.

**Estimated Implementation Time**: 2-3 days for MVP (including tests and documentation)

**Critical Path**: Database migrations → Workers → Event integration → Public page

**Risk Areas**:
- Spotify API rate limits (mitigated by backoff)
- Consecutive track detection (application-level check, not database constraint)
- Table growth (mitigated by retention policy cleanup)
