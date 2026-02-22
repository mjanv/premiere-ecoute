# Improvement Opportunities

## 1. Code Duplication

### `token_expired?/1` defined twice
`TokenRenewal` and `TwitchQueue` both define the exact same private function. Move it to `TokenRenewal` and call it from `TwitchQueue`.
- `lib/premiere_ecoute/accounts/services/token_renewal.ex:39-40`
- `lib/premiere_ecoute/apis/streaming/twitch_queue.ex:86-87`

### `session_status_class/1` and `visibility_label/1` duplicated across LiveViews
Three LiveViews each define their own variant of these helpers. Move them to `SessionComponents`.
- `lib/premiere_ecoute_web/live/sessions/session_live.ex:333`
- `lib/premiere_ecoute_web/live/sessions/sessions_live.ex:93`
- `lib/premiere_ecoute_web/live/admin/admin_sessions_live.ex:106`

### `pagination_range/2` duplicated in two admin LiveViews
- `lib/premiere_ecoute_web/live/admin/admin_sessions_live.ex:116-130`
- `lib/premiere_ecoute_web/live/admin/admin_albums_live.ex:80-94`

### Period navigation helpers duplicated between retrospective LiveViews
`parse_year/1`, `parse_month/1`, `build_params/3`, `get_available_years/0` are copy-pasted verbatim.
- `lib/premiere_ecoute_web/live/retrospective/history_live.ex`
- `lib/premiere_ecoute_web/live/retrospective/votes_live.ex`

### `open_album` / `open_playlist` Oban worker clauses nearly identical
Both clauses in `ListeningSessionWorker` do the same thing (load user+session, write cache, send chat, broadcast) differing only on one field. Collapse into a single clause.
- `lib/premiere_ecoute/sessions/listening_session/listening_session_worker.ex:25-55`

---

## 2. Potential Bugs

### `Report.generate/1` — non-exhaustive `case` on `vote_options`
A session with custom options (e.g. `["A", "B", "C"]`) will crash with `CaseClauseError` at runtime. Add a fallback clause.
- `lib/premiere_ecoute/sessions/retrospective/report.ex:98-103`

### `Store.append/2` silently discards write errors
`append_to_stream` and `link_to_stream` return `{:ok, ...}` or `{:error, ...}`, but results are ignored. The function always returns `:ok`, swallowing event store failures.
- `lib/premiere_ecoute/events/store.ex:78-83`

### `ListeningSessionWorker` — `next_track` missing `:ok` return
The `next_track` clause has no explicit `:ok` after the `with` block. A failing command will cause Oban to mark the job failed instead of discarding it. Compare with `next_playlist_track` which does return `:ok`.
- `lib/premiere_ecoute/sessions/listening_session/listening_session_worker.ex:80-86`

### `Account.delete_account/1` — nil Twitch association causes mid-transaction crash
`v.viewer_id == ^user.twitch.user_id` will raise if the user never connected Twitch. Add a guard for a nil association before constructing the query.
- `lib/premiere_ecoute/accounts/services/account_compliance.ex:80`

### `VoteTrends.rolling_average/2` — SQL `CAST AS NUMERIC` fails on text votes
For smash/pass sessions, casting `"smash"` or `"pass"` to numeric raises a PostgreSQL error. Add a type guard before executing the query.
- `lib/premiere_ecoute/sessions/retrospective/vote_trends.ex:133-149`

### `SpotifyPlayer` — end-of-track detection is brittle
`{98, 99}` exact match will miss the end of track if the polling interval skips those specific percentages. Use `b >= 99` instead.
- `lib/premiere_ecoute/apis/players/spotify_player.ex:117-121`

### `Retrospective.History` — hardcoded `smash/pass` exclusion in vote query
`where: v.value not in ["smash", "pass"]` will silently include future text-mode options in numeric averages. Tie exclusion to session vote type instead.
- `lib/premiere_ecoute/sessions/retrospective/history.ex:67`

---

## 3. Performance Issues

### `AdminSessionsLive` — loads all sessions into memory for stats
Fetches every session record to compute status distribution. Replace with a single `COUNT ... GROUP BY status` query.
- `lib/premiere_ecoute_web/live/admin/admin_sessions_live.ex:20-21`

### `AdminUsersLive` — loads all users into memory, no pagination
Same pattern as above. Add pagination and use `COUNT ... GROUP BY role` for stats.
- `lib/premiere_ecoute_web/live/admin/admin_users_live.ex:21-22`

### `Balance.compute_balance/1` — `force: true` preload inside a pure function
Always re-fetches from DB even on repeated calls. Move preloading to the caller; keep this function pure.
- `lib/premiere_ecoute/donations/services/balance.ex:28`

### `SessionLive` — 1 Hz cache poll for `open_vote` is redundant
`:refresh` message polls the cache every second, but `open_vote` state is already pushed via PubSub (`:vote_open` / `:vote_close`). Remove the poller.
- `lib/premiere_ecoute_web/live/sessions/session_live.ex:197-205`

### `TwitchQueue` — uses list `++` instead of a proper queue
Appending with `++` is O(n). Use `:queue` (as `BroadwayProducer` already does) for O(1) enqueue/dequeue.
- `lib/premiere_ecoute/apis/streaming/twitch_queue.ex:50, 75`

### `SpotifyPlayer` — polls Presence on every tick (1.5 s)
Subscribe to presence change events via PubSub instead of calling `Presence.player/1` on each tick.
- `lib/premiere_ecoute/apis/players/spotify_player.ex:64`

---

## 4. Ecto Queries Outside Context Modules

### `VotesLive` — raw Ecto queries in a LiveView
`Repo.get(Album, ...)` and `get_all_track_votes_for_user/2` belong in `Discography` or `Sessions` context.
- `lib/premiere_ecoute_web/live/retrospective/votes_live.ex:135, 153-162`

### `DonationsLive` — calls `Repo.delete/1` directly
Bypasses the `Donations` context entirely. Add a `Donations.delete_goal/1` function.
- `lib/premiere_ecoute_web/live/admin/donations/donations_live.ex:132`

---

## 5. OTP Issues

### `SpotifyPlayer` — double Presence join, no GenServer-side unjoin
The GenServer calls `Presence.join` in `init/1`, and the LiveView also calls it on mount. The GenServer has no `terminate/2` with `Presence.unjoin`, so presence can leak if the GenServer outlives the LiveView.
- `lib/premiere_ecoute/apis/players/spotify_player.ex:40`
- `lib/premiere_ecoute_web/live/sessions/session_live.ex:37`

---

## 6. Error Handling

### `BuyMeACoffeeController` — returns `202` on DB insertion failure
A failed donation insert returns `202 Accepted` to the webhook provider, preventing retries. The donation is silently lost. Return a `5xx` status so the provider retries.
- `lib/premiere_ecoute_web/controllers/webhooks/buy_me_a_coffee_controller.ex:46-48`

### `CommandBus` — events dispatched on the error path
`{:error, events}` still calls `EventBus.dispatch(events)`, causing side effects to fire for failed commands. Evaluate whether error-path events should be dispatched or suppressed.
- `lib/premiere_ecoute_core/command_bus.ex:44-48`

### `EventBus.dispatch/1` — no early exit on unregistered handler
Processing continues even when an event has no registered handler. Errors are logged but not surfaced or accumulated.
- `lib/premiere_ecoute_core/event_bus.ex:25-28`

---

## 7. LiveView Anti-Patterns

### `HistoryLive` and `VotesLive` — data loaded in both `mount/3` and `handle_params/3`
On initial load, the async task starts twice. Move all param-driven data loading exclusively to `handle_params/3`.
- `lib/premiere_ecoute_web/live/retrospective/history_live.ex:30-34, 56-59`
- `lib/premiere_ecoute_web/live/retrospective/votes_live.ex:43-47, 71-75`

---

## 8. Dead Code

### Commented-out functions in `User` schema
Four commented-out function stubs below line 218. Remove them — the implementations live in `OauthToken` and are exposed via `defdelegate`.
- `lib/premiere_ecoute/accounts/user.ex:218-227`

### `Retrospective.History.get_tracks_by_period/4` — no call site
Function is defined but never delegated or called from the web layer.
- `lib/premiere_ecoute/sessions/retrospective/history.ex:129-171`

### `Sessions.start_session/1` and `stop_session/1` delegates may be vestigial
All call sites invoke commands through `PremiereEcoute.apply/1` directly; these context-level delegates appear unused.
- `lib/premiere_ecoute/sessions.ex`
