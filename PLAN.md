# Daily Playlist Feature - Implementation

## Feature

"What was this title you streamed today ?"

Whenever a stream is started, a Spotify player instance is spun up and used to track every track played during a stream by querying the API every minute to retrieve every listened song. Whenever a new song is detected, it is registered in the day playlist of the streamer. The Spotify player goes inactive whenever the stream ends.

The feature can be activated or not by the streamer. A public page is available for viewers to see which tracks have been played on a specific day. Older day playlists can be automatically deleted (1 week after for example).

---

## Status: Implemented

---

## Database Schema

### Table: `radio_tracks`

```sql
create table(:radio_tracks) do
  add :user_id, references(:users, on_delete: :delete_all), null: false
  add :provider_id, :string, null: false
  add :name, :string, null: false
  add :artist, :string, null: false
  add :album, :string
  add :duration_ms, :integer
  add :started_at, :utc_datetime, null: false
  timestamps()
end

create index(:radio_tracks, [:user_id, :started_at])
create index(:radio_tracks, [:started_at])
```

### User Settings Extension

`User.Profile` extended with `radio_settings` embed:

```elixir
embeds_one :radio_settings, RadioSettings, on_replace: :update do
  field :enabled, :boolean, default: false
  field :retention_days, :integer, default: 7
  field :visibility, Ecto.Enum, values: [:private, :public], default: :public
end
```

---

## Components

### Schema: `RadioTrack` (`lib/premiere_ecoute/radio/radio_track.ex`)

Fat schema following the `PremiereEcouteCore.Aggregate` pattern. Contains all query/insert logic:

- `insert/2` — inserts a new track, preventing consecutive duplicates
- `last_for_user/1` — fetches the most recent track for a user
- `for_date/2` — returns all tracks for a user on a specific date
- `delete_before/2` — deletes tracks older than a cutoff datetime

### Context: `Radio` (`lib/premiere_ecoute/radio.ex`)

Thin context delegating to `RadioTrack`:

```elixir
defdelegate insert_track(user_id, track_data), to: RadioTrack, as: :insert
defdelegate get_tracks(user_id, date),         to: RadioTrack, as: :for_date
defdelegate delete_tracks_before(user_id, cutoff_datetime), to: RadioTrack, as: :delete_before
```

### Worker: `TrackSpotifyPlayback` (`lib/premiere_ecoute/radio/workers/track_spotify_playback.ex`)

Self-scheduling Oban worker (queue: `:spotify`, max_attempts: 3):

- Polls Spotify playback state on each execution
- `started_at` is computed as `DateTime.utc_now() - progress_ms` when available, falls back to detection time
- Next poll is scheduled at `(duration_ms - progress_ms + 30_000) / 1000` seconds when playback info is available, falls back to 60 seconds
- Stops scheduling when feature is disabled (graceful shutdown)
- Rate limit backoff: 5 minutes on 429

### Worker: `CleanupOldTracks` (`lib/premiere_ecoute/radio/workers/cleanup_old_tracks.ex`)

Oban worker (queue: `:cleanup`, max_attempts: 1) scheduled via cron (`0 0,12 * * *` — midnight and noon UTC):

- Iterates over streamers with `radio_settings.enabled: true`
- Deletes tracks older than `retention_days` per user

### Events: `StreamStarted` / `StreamEnded` (`lib/premiere_ecoute/events/twitch.ex`)

```elixir
defmodule PremiereEcoute.Events.Twitch.StreamStarted do
  defstruct [:broadcaster_id, :broadcaster_name, :started_at]
end

defmodule PremiereEcoute.Events.Twitch.StreamEnded do
  defstruct [:broadcaster_id, :broadcaster_name]
end
```

### Event Integration

`TwitchController.handle/1` returns `%StreamStarted{}` / `%StreamEnded{}` structs for `stream.online` / `stream.offline` webhooks. The controller broadcasts them to `"twitch:events"` via PubSub.

### GenServer: `Radio.EventHandler` (`lib/premiere_ecoute/radio/event_handler.ex`)

Subscribes to `"twitch:events"` PubSub topic:

- `StreamStarted` → looks up user by Twitch ID, enqueues `TrackSpotifyPlayback` if `radio_settings.enabled: true`
- `StreamEnded` → no-op (polling stops naturally on next iteration)

Registered in `PremiereEcoute.Supervisor`.

### LiveView: `Radio.ViewerLive` (`lib/premiere_ecoute_web/live/radio/viewer_live.ex`)

Public page at `/radio/:username`, `/radio/:username/today`, `/radio/:username/:date`:

- Checks `radio_settings.visibility == :public`
- Date navigation: left arrow goes back one day, right arrow goes forward (disabled on today)
- Uses `push_patch` for client-side navigation between dates (no full reload)
- Lookup by username via `Accounts.get_user_by_username/1`

### LiveView: `Accounts.AccountFeaturesLive` (`lib/premiere_ecoute_web/live/accounts/account_features_live.ex`)

Settings page at `/users/account/features`, accessible to streamers and admins only:

- Gated by `role in [:streamer, :admin]` and `:radio` feature flag
- Compact settings list: enable toggle, visibility, retention days
- Linked from `/users/account` via "Streamer Features" button (same live_session, no full reload)

---

## Data Flow

### Stream Start

```
Twitch EventSub: stream.online
  → TwitchController.handle/1 → %StreamStarted{}
  → PubSub.broadcast("twitch:events", {:stream_event, %StreamStarted{}})
  → Radio.EventHandler → enqueue TrackSpotifyPlayback
  → polling loop starts
```

### Polling Loop

```
TrackSpotifyPlayback.perform/1
  → get_playback_state/2
  → Radio.insert_track/2 (consecutive duplicate check)
  → schedule next poll at (remaining_ms + 30s), or 60s fallback
```

### Stream End

```
Twitch EventSub: stream.offline
  → TwitchController.handle/1 → %StreamEnded{}
  → PubSub.broadcast("twitch:events", {:stream_event, %StreamEnded{}})
  → Radio.EventHandler → no-op
  → polling stops on next iteration (feature_enabled? returns false or no reschedule)
```

---

## Design Decisions

- **`started_at` precision**: Computed from `progress_ms` when available (`now - progress_ms`), not just detection time
- **Adaptive polling**: Next poll scheduled at track end + 30s buffer, not fixed 60s
- **Consecutive duplicate prevention**: Application-level check in `RadioTrack.insert/2`, not a DB constraint
- **Fat schema / thin context**: Business logic lives in `RadioTrack`, `Radio` context only delegates
- **Complete decoupling**: No foreign keys to discography tables — only `user_id → users`
- **Retention per user**: Each user's `retention_days` setting is respected independently by `CleanupOldTracks`
- **No real-time updates on viewer page**: Static load on mount and date navigation; PubSub broadcast not implemented
- **Feature flag**: `:radio` flag gates sidebar link, account features page, and streamer settings link
- **User lookup by username**: `Accounts.get_user_by_username/1` added to support the public URL scheme
- **`radio_settings` primary_key: false**: Inline `embeds_one` block requires explicit `primary_key: false` to avoid Ecto autogenerate errors on save
