# CollectionSession — Implementation Plan

## Concept

A CollectionSession lets a streamer curate a Spotify playlist live on stream. Songs from an
origin playlist are played one by one (or two at a time in duel mode). Viewers and the streamer
vote on each track. At the end, the streamer syncs the kept tracks to a destination Spotify
playlist.

## Selection modes

| Mode | How it works |
|---|---|
| `streamer_choice` | Streamer clicks Keep / Skip / Reject directly |
| `viewer_vote` | Chat votes `1` (yes) or `2` (no); timer closes; streamer finalizes |
| `duel` | Two random undecided tracks; chat votes `1` (track A) or `2` (track B); timer closes; streamer finalizes |

In all modes the **streamer makes the final decision**. Votes are informational.

## Data model

### `collection_sessions`
```
id                        serial PK
user_id                   FK → users
origin_playlist_id        FK → library_playlists
destination_playlist_id   FK → library_playlists
status                    enum(:pending, :active, :completed)
rule                      enum(:ordered, :random)
selection_mode            enum(:streamer_choice, :viewer_vote, :duel)
vote_duration             integer (seconds, nullable — viewer_vote and duel only)
current_index             integer default 0
inserted_at, updated_at
```

### `collection_decisions`
```
id                        serial PK
collection_session_id     FK → collection_sessions
track_id                  string (Spotify track ID)
track_name                string
artist                    string
position                  integer (original position in origin playlist)
decision                  enum(:kept, :rejected, :skipped)
votes_a                   integer default 0  (yes / track A)
votes_b                   integer default 0  (no  / track B)
duel_track_id             string nullable    (duel: the other track in the round)
decided_at                utc_datetime
inserted_at, updated_at
```

Origin playlist tracks are **not stored** — fetched from Spotify at StartCollectionSession,
optionally shuffled, then cached in ETS keyed by session_id. CollectionDecision is the only
persistent artifact.

## Commands

```
PrepareCollectionSession   user_id, origin_playlist_id, destination_playlist_id,
                           rule, selection_mode, vote_duration
StartCollectionSession     session_id, scope
DecideTrack                session_id, scope, track_id, decision (:kept|:rejected|:skipped),
                           duel_track_id (nullable, duel loser)
OpenVoteWindow             session_id, scope
CloseVoteWindow            session_id, scope
CompleteCurationSession    session_id, scope
```

## Events

```
CollectionSessionPrepared  session_id, user_id
CollectionSessionStarted   session_id, user_id
TrackDecided               session_id, user_id, track_id, decision
VoteWindowOpened           session_id, user_id, track_id, mode (:viewer_vote|:duel)
VoteWindowClosed           session_id, user_id, track_id
CollectionSessionCompleted session_id, user_id
```

## Vote pipeline

Reuses Broadway pattern from MessagePipeline. One shared `CollectionMessagePipeline`:
- Cache key: `{:collections, broadcaster_id}`
- Cache entry: `%{session_id, track_id, duel_track_id, selection_mode, vote_duration}`
- `"1"` → `votes_a` increment (yes / track A)
- `"2"` → `votes_b` increment (no / track B)
- Broadcasts `{:vote_update, %{votes_a, votes_b}}` to `collection:#{session_id}` PubSub topic

## Oban worker

`CollectionSessionWorker` handles:
- `"open_vote"` — puts cache entry, sends Twitch chat message, broadcasts `:vote_open`
- `"close_vote"` — removes cache entry, broadcasts `:vote_close` with final counts

vote_duration controls the delay between open and close jobs.

## File structure

```
lib/premiere_ecoute/collections/
  collection_session.ex
  collection_decision.ex
  collection_session/
    commands.ex
    events.ex
    command_handler.ex
    event_handler.ex
    collection_session_worker.ex
    message_pipeline.ex

lib/premiere_ecoute_web/live/collections/
  collection_sessions_live.ex          /collections
  collection_sessions_live.html.heex
  collection_session_new_live.ex       /collections/new
  collection_session_new_live.html.heex
  collection_session_live.ex           /collections/:id
  collection_session_live.html.heex

priv/repo/migrations/
  _create_collection_sessions.exs
  _create_collection_decisions.exs

test/premiere_ecoute/collections/
  collection_session_test.exs
  collection_decision_test.exs
  command_handler_test.exs
  event_handler_test.exs
  message_pipeline_test.exs
```

## UI pages

### `/collections` — list
Past and active sessions. Shows origin → destination playlist names, mode badge,
progress (N kept / M total), status badge, link to session.

### `/collections/new` — creation form
Single page:
1. Origin playlist (dropdown from user's library)
2. Destination playlist (same list)
3. Rule: ordered / random
4. Selection mode: streamer choice / viewer vote / duel
5. Vote duration (shown only for viewer_vote and duel): 30s / 1m / 2m / 5m

### `/collections/:id` — main UI

**Streamer choice**: single track card, Keep / Skip / Reject buttons, progress sidebar.

**Viewer vote**: single track card, Play/Stop buttons, vote bar (yes/no counts), countdown
timer, Keep / Reject buttons (enabled after timer closes).

**Duel**: two track cards side by side, Play A / Play B buttons, vote bar per track (1/2
counts), countdown timer, Pick A / Pick B buttons (enabled after timer closes).

All modes share a progress sidebar (kept = green, rejected = red, skipped = gray).

Completion screen: summary stats + "Sync to Spotify" button that triggers
CompleteCurationSession → adds all :kept decisions to destination playlist in order.

## Build order

- [ ] 1. Migrations: collection_sessions, collection_decisions
- [ ] 2. CollectionSession schema + aggregate
- [ ] 3. CollectionDecision schema + aggregate
- [ ] 4. Commands + Events (structs only)
- [ ] 5. CommandHandler: Prepare, Start, DecideTrack, Complete
- [ ] 6. CommandHandler: OpenVoteWindow, CloseVoteWindow
- [ ] 7. EventHandler: PubSub, cache, Oban scheduling
- [ ] 8. CollectionSessionWorker: open_vote, close_vote
- [ ] 9. CollectionMessagePipeline: Broadway chat pipeline
- [ ] 10. Unit tests: schemas, command handler, event handler, pipeline
- [ ] 11. Router: /collections scope under :streamer live_session
- [ ] 12. CollectionSessionsLive: list page
- [ ] 13. CollectionSessionNewLive: creation form
- [ ] 14. CollectionSessionLive: main UI (all three mode variants)
