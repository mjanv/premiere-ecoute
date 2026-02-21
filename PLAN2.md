# Spotify Rate Limit Circuit Breaker

## Context

Spotify's `/me/player` endpoint is aggressively rate-limiting the app (429 with `retry-after: 36537` ~10 hours). The app polls this endpoint at 1-second intervals (SpotifyPlayer GenServer) plus 60-second Oban workers per user. There is no global circuit breaker — a 429 causes SpotifyPlayer to crash (`:stop, {:error, reason}`) without coordinated recovery.

Goal: detect 429s, open a global circuit breaker, keep listening sessions alive in degraded mode, and surface the incident to all users via a site banner.

---

## Architecture: `SpotifyCircuitBreaker` GenServer

A single supervised GenServer holds global Spotify circuit state. States: `:closed` → `:open` → auto-reset to `:closed` via `Process.send_after` using the `retry-after` value.

State shape:
```elixir
%{
  status: :closed | :open,
  open_until: DateTime.t() | nil,
  call_counts: %{String.t() => non_neg_integer()}  # "GET /me/player" => 42
}
```

Public API:
- `allow?/0` — check before every Spotify HTTP call
- `record_call(route)` — increment counter per route
- `record_rate_limit(retry_after_seconds)` — open circuit, schedule reset
- `status/0` — returns current state for banner/admin display

On state change: broadcast `{:spotify_circuit, :open, open_until}` or `{:spotify_circuit, :closed}` via `PremiereEcoute.PubSub.broadcast("spotify:circuit", ...)`.

---

## Steps

### 1. New: `lib/premiere_ecoute/apis/spotify_circuit_breaker.ex`

GenServer implementing the interface above. Auto-resets via `handle_info(:reset, state)` scheduled at `record_rate_limit/1` time using `Process.send_after(self(), :reset, retry_after * 1000)`.

### 2. Add to `lib/premiere_ecoute/apis/supervisor.ex`

Add `PremiereEcoute.Apis.SpotifyCircuitBreaker` to the mandatory children list alongside the existing caches.

### 3. `lib/premiere_ecoute/apis/music_provider/spotify_api/player.ex`

Two changes:

**Guard at the top of `get_playback_state/2` and all other player functions:**
```elixir
if not SpotifyCircuitBreaker.allow?(), do: {:error, :spotify_unavailable}
```

**429 clause** — extract `retry-after` from response headers and call:
```elixir
SpotifyCircuitBreaker.record_rate_limit(retry_after_seconds)
```

### 4. `lib/premiere_ecoute/telemetry/api_metrics.ex`

In `api_call/2`, for provider `:spotify`, also call `SpotifyCircuitBreaker.record_call(request.url.path)`. This feeds the per-route counters (requirement 1) without touching any call sites.

### 5. `lib/premiere_ecoute/apis/players/spotify_player.ex`

In `handle_info(:poll, ...)`, distinguish the new error:
- `{:error, :spotify_unavailable}` → stay alive, skip poll cycle, reschedule. Broadcast `:degraded` to the player PubSub channel. Do NOT stop the process.
- Other errors → existing crash behavior unchanged.

This keeps listening sessions alive (requirement 5): the session continues, the player just pauses updates until the circuit closes.

### 6. `lib/premiere_ecoute/radio/workers/track_spotify_playback.ex`

Add a guard at the top of `perform/1`:
```elixir
with true <- SpotifyCircuitBreaker.allow?() || {:error, :spotify_unavailable},
     ...
```
On `:spotify_unavailable`: snooze the Oban job for the remaining seconds from `SpotifyCircuitBreaker.status().open_until`.

### 7. New: `lib/premiere_ecoute_web/hooks/spotify_status.ex`

LiveView hook (mirroring `lib/premiere_ecoute_web/hooks/flash.ex`) that:
- Subscribes all authenticated users to `"spotify:circuit"` PubSub topic on mount
- Reads initial state from `SpotifyCircuitBreaker.status()` on mount
- Handles `{:spotify_circuit, :open, open_until}` → assigns `spotify_unavailable: true`
- Handles `{:spotify_circuit, :closed}` → assigns `spotify_unavailable: false`

### 8. `lib/premiere_ecoute_web/components/navigation/header.ex`

Add an orange banner (same pattern as the impersonation banner) rendered when `@spotify_unavailable`:
```
⚠ Spotify API is temporarily unavailable. Expected recovery: {format_datetime(@spotify_retry_at)}.
```

Attach the `SpotifyStatus` hook in the same place as the `Flash` hook (root layout or app-level LiveView).

---

## Files

| Action | File |
|--------|------|
| Create | `lib/premiere_ecoute/apis/spotify_circuit_breaker.ex` |
| Create | `lib/premiere_ecoute_web/hooks/spotify_status.ex` |
| Modify | `lib/premiere_ecoute/apis/supervisor.ex` |
| Modify | `lib/premiere_ecoute/apis/music_provider/spotify_api/player.ex` |
| Modify | `lib/premiere_ecoute/telemetry/api_metrics.ex` |
| Modify | `lib/premiere_ecoute/apis/players/spotify_player.ex` |
| Modify | `lib/premiere_ecoute/radio/workers/track_spotify_playback.ex` |
| Modify | `lib/premiere_ecoute_web/components/navigation/header.ex` |
| Modify | Root layout or app LiveView (attach SpotifyStatus hook) |

---

## Verification

```bash
mix test  # must pass
```

In IEx:
```elixir
PremiereEcoute.Apis.SpotifyCircuitBreaker.record_rate_limit(60)
PremiereEcoute.Apis.SpotifyCircuitBreaker.allow?()  # => false
# Banner appears on all authenticated pages
# After 60s: allow?() => true, banner disappears
```

Check Grafana: `premiere_ecoute_apis_api_call_count` has per-route breakdown for Spotify.
