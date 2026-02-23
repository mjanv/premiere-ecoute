# Improvement Opportunities

### `SpotifyPlayer` — double Presence join, no GenServer-side unjoin
The GenServer calls `Presence.join` in `init/1`, and the LiveView also calls it on mount. The GenServer has no `terminate/2` with `Presence.unjoin`, so presence can leak if the GenServer outlives the LiveView.
- `lib/premiere_ecoute/apis/players/spotify_player.ex:40`
- `lib/premiere_ecoute_web/live/sessions/session_live.ex:37`

