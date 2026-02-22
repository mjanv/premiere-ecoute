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

### `VoteTrends.rolling_average/2` — SQL `CAST AS NUMERIC` fails on text votes
For smash/pass sessions, casting `"smash"` or `"pass"` to numeric raises a PostgreSQL error. Add a type guard before executing the query.
- `lib/premiere_ecoute/sessions/retrospective/vote_trends.ex:133-149`

### `Retrospective.History` — hardcoded `smash/pass` exclusion in vote query
`where: v.value not in ["smash", "pass"]` will silently include future text-mode options in numeric averages. Tie exclusion to session vote type instead.
- `lib/premiere_ecoute/sessions/retrospective/history.ex:67`

---

## 3. Performance Issues

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

---

## 7. LiveView Anti-Patterns

### `HistoryLive` and `VotesLive` — data loaded in both `mount/3` and `handle_params/3`
On initial load, the async task starts twice. Move all param-driven data loading exclusively to `handle_params/3`.
- `lib/premiere_ecoute_web/live/retrospective/history_live.ex:30-34, 56-59`
- `lib/premiere_ecoute_web/live/retrospective/votes_live.ex:43-47, 71-75`

---

## 8. Dead Code

### `Sessions.start_session/1` and `stop_session/1` delegates may be vestigial
All call sites invoke commands through `PremiereEcoute.apply/1` directly; these context-level delegates appear unused.
- `lib/premiere_ecoute/sessions.ex`
