# Desktop player hand-off

Backend contract for the Rust desktop player (`apps/desktop-player`). This document supersedes sections 4, 5 and 13 of ADR 0001 wherever they differ. Branch: `feat/rust-player` of this repository.

## Status

Implemented and covered by backend tests: OAuth enrollment, the socket and channel, the playback state follow, command routing with Web API fallback, revocation. Verified live over a real WebSocket on a dev server with the Rust player: join, snapshots, `play_uri`, `toggle_play_pause`, `next`, and the fall back to Web API polling on disconnect. Not verified live: refresh rotation, revoke from the account page, `replaced`.

## What changed from the ADR

| ADR | Now |
|---|---|
| `X-Device-Id` header, `device_id`, `POST /api/player/devices` | **Removed.** One player per user, the access token identifies the user. No registration step. |
| Topic `device:<id>` | Topic **`desktop:me`** (`desktop:<user_id>` also accepted). |
| URL `/device/websocket` | **`/player/websocket`** |
| Snapshot has no track identity | Snapshot carries **`uri`** (required key, may be `null`). |
| Several devices per user | **Exactly one.** A new join replaces the previous connection. |

## Dev setup (backend)

1. `git checkout feat/rust-player`, then `docker compose up -d` and `mix ecto.migrate`. Two new migrations create the `player` OAuth scope and the OAuth client.
2. `mix` (server on `http://localhost:4000`; `ws://localhost:4000/player/websocket` for the socket).
3. Log in once in a browser at `http://localhost:4000` with your Twitch account (needed for the consent screen).

If you run a worktree, the port differs: see `docs/guides/worktrees.md`.

## Constants

| Name | Value |
|---|---|
| Base URL (dev) | `http://localhost:4000` |
| `client_id` | `6c1d8f0e-3a52-4b7e-9e41-2f5a7c9d8b13` (public client, **no secret**) |
| Scope | `player` (only this one; do not request `mcp`) |
| Redirect URI | `http://127.0.0.1:<port>/cb`. Port must be 3 to 63 alphanumeric characters, so any real port (1000-65535) works. Host must be exactly `127.0.0.1`, scheme `http`, path `/cb`. |
| Access token lifetime | 1 hour |
| Refresh token lifetime | 30 days, **rotated on every refresh** |

## Enrollment (OAuth 2.1, authorization code + PKCE S256)

1. Generate `code_verifier` (64 random characters from `[A-Za-z0-9-._~]`), `code_challenge = base64url_nopad(sha256(verifier))`, a random `state`. Listen on `127.0.0.1:<port>`.
2. Open in the default browser:

   ```
   GET http://localhost:4000/oauth/authorize
       ?response_type=code
       &client_id=6c1d8f0e-3a52-4b7e-9e41-2f5a7c9d8b13
       &redirect_uri=http%3A%2F%2F127.0.0.1%3A<port>%2Fcb
       &scope=player
       &state=<state>
       &code_challenge=<challenge>
       &code_challenge_method=S256
   ```

   The user is sent to login if needed, then sees a consent screen and approves.
3. The browser is redirected to `http://127.0.0.1:<port>/cb?code=...&state=...` (or `?error=access_denied&...`). Check `state` before anything else.
4. Exchange the code (form-encoded, no client secret):

   ```
   POST http://localhost:4000/oauth/token
   Content-Type: application/x-www-form-urlencoded

   grant_type=authorization_code&code=<code>&redirect_uri=<same uri>&client_id=<client_id>&code_verifier=<verifier>
   ```

   Response `200`: `{"token_type":"Bearer","access_token":"...","expires_in":3600,"refresh_token":"..."}`. Errors are `{"error":"...","error_description":"..."}` with status 4xx. Codes live 60 seconds.
5. Store the refresh token (Credential Manager). Keep the access token in memory.

**Refresh** (when `expires_in` is under 60 s, and before every reconnect):

```
POST /oauth/token
grant_type=refresh_token&refresh_token=<token>&client_id=<client_id>
```

The response contains a **new** refresh token and the old one is revoked immediately. Persist the new one before using the new access token. `invalid_grant` means the credential is dead: go to `Unauthorized`, ask the user to log in again.

**Forget this PC**:

```
POST /oauth/revoke
client_id=<client_id>&token=<refresh_token>&token_type_hint=refresh_token
```

`200` with an empty body.

## WebSocket

- URL: `ws://localhost:4000/player/websocket?vsn=2.0.0` (production: `wss://`).
- Header on the upgrade request: `X-Access-Token: <access token>`. No other header, no query parameter. The player sends no `Origin`, which is accepted.
- Failed authentication (unknown, expired, revoked token, or a token without the `player` scope) answers the upgrade with an HTTP error: refresh the token once, then treat a second failure as `Unauthorized`.
- Frames: Phoenix V2 JSON arrays `[join_ref, ref, topic, event, payload]`. Max frame 64 KiB.
- Heartbeat: `[null, ref, "phoenix", "heartbeat", {}]` every 25 s. The server drops an idle socket after 60 s.

### Join

```json
[ "1", "1", "desktop:me", "phx_join",
  {"proto": 1, "app_version": "0.1.0", "session_id": "<uuid, new per process start>"} ]
```

Reply (`phx_reply`): `{"status":"ok","response":{"snapshot_interval_ms":1000}}`, or `{"status":"error","response":{"reason":"forbidden" | "unsupported_protocol"}}`.

On join the backend starts the user's player process and switches it to local mode. **Send the first snapshot immediately after the join reply.** If no snapshot arrives for 5 seconds the backend falls back to the Spotify Web API and ignores the player until the next join.

### Device to server

`snapshot`, once per `snapshot_interval_ms` (1000):

```json
{"seq": 42,
 "snapshot": {
   "running": true,
   "playback": "playing",
   "uri": "spotify:track:6rqhFgbbKwnb9MLmUQDhG6",
   "title": "...", "artist": "...", "album": "...",
   "position_ms": 12345, "length_ms": 215000,
   "volume": 0.5 }}
```

- `seq` is an integer increasing by 1 per snapshot per connection (start at 1). The backend ignores any `seq` not greater than the last one.
- `running`: boolean. `playback`: `"playing" | "paused" | "stopped"`. `volume`: number in `0.0..1.0` or `null`. `position_ms`, `length_ms`: non-negative integers. `uri`: `null` when unknown or not a track. Strings are cut to 512 characters.
- All of `running`, `playback`, `position_ms`, `length_ms` are required; `volume` may be `null`; unknown keys are ignored.
- Send `running: false` (and `uri: null`) when Spotify desktop is not running: the backend then reports "no device".
- The backend uses `uri` to detect track changes, so it must change when the track changes.

`ack`, exactly one per received `command`:

```json
{"command_id": "<uuid>", "status": "ok" | "error" | "rejected" | "expired" | "duplicate", "error": "<optional text>"}
```

`rejected`, `expired` and `error` **must mean the action was not performed**: the backend then runs the command through the Spotify Web API instead. `ok` must mean Spotify accepted it. Never ack `error` for something that partially ran. A missing ack is treated as "unknown" and is **not** retried anywhere.

### Server to device

`command`:

```json
{"id": "<uuid>", "type": "play_uri", "args": {"uri": "spotify:track:<22 alphanumeric>"}, "ttl_ms": 10000}
```

| `type` | `args` | Sent today by the backend |
|---|---|---|
| `play_uri` | `{"uri": "spotify:track:..."}` | Yes (session track start, next, previous, resume) |
| `toggle_play_pause` | `{}` | Yes, only to pause a session that is playing |
| `next`, `previous` | `{}` | Only on demand through `SpotifyPlayer.command/3`; no session flow sends them |
| `set_volume` | `{"volume": 0.0..1.0}` | Only on demand through `SpotifyPlayer.command/3` |

Rules the player must apply (the backend relies on them):
- `ttl_ms` is relative. Start a timer on receipt; if it elapsed before execution, do not run it and ack `expired`.
- Keep the last 256 command ids with their result. A repeated id is not executed again: ack `duplicate`.
- Re-validate every command (type allow-list, URI format `spotify:track:` plus 22 alphanumeric characters, volume range) and ack `rejected` on failure.
- Execute at most once. Never re-run a command after a reconnect.

`disconnect` (the channel then closes, the socket may stay open):

```json
{"reason": "replaced" | "revoked"}
```

- `replaced`: another connection of the same user took over. Close the socket and wait at least 60 s before reconnecting.
- `revoked`: the user disconnected the player or the tokens were revoked. Go to `Unauthorized`; do not reconnect before a new login.

`config` is reserved and never sent yet. Ignore unknown events.

### Backend limits

| Behaviour | Limit |
|---|---|
| Snapshots above 5 per second | Dropped |
| Snapshots above 20 per second | Channel closed |
| Invalid `snapshot` or `ack` payloads | 10 within 60 s closes the channel |
| Revocation re-check | Every 5 minutes, then `disconnect: revoked` |
| Command without ack | Unknown after `ttl_ms` + 2 s |

## What the backend does with the player

- **Playback state**: while connected, the backend does not poll the Spotify Web API for this user. Overlay, session scoring and track events are driven by the snapshots.
- **Commands**: session start, next track, previous track, resume and stop go to the player first. What the desktop player cannot do (albums and playlists as a context, resuming at a position, shuffle, repeat) is sent to the Web API, or skipped.
- **Disconnect or silence** (socket closed, or no snapshot for 5 s): the backend returns to Web API polling by itself, with a fresh budget. Reconnect with jittered backoff (`random(0, min(60 s, 1 s * 2^attempt))`, reset after 30 s of stable connection).

## End-to-end test with your account

1. Backend running as above, you are logged in at `http://localhost:4000`, Spotify desktop is running.
2. Player: run the enrollment, log in with your Twitch account, approve. Expect a refresh token stored and an access token.
3. Player: open the socket, join `desktop:me`, send snapshots every second. Expect the join reply `ok`.
4. Backend side, confirm the switch: in `iex --remsh dev --sname local`:

   ```elixir
   Phoenix.PubSub.subscribe(PremiereEcoute.PubSub, "playback:<your user id>")
   flush()   # expect {:player, {:mode, :local}, _} after a join
   ```

5. Run a command from the backend, replacing the user id and a track id:

   ```elixir
   alias PremiereEcoute.Accounts.{Scope, User}
   scope = Scope.for_user(User.get(<your user id>))
   track = %PremiereEcoute.Discography.Album.Track{provider_ids: %{spotify: "6rqhFgbbKwnb9MLmUQDhG6"}}
   PremiereEcoute.Apis.Players.SpotifyPlayer.command(scope, {:play, track}, fn -> {:ok, :web_api} end)
   ```

   Expected: `{:ok, "spotify:track:6rqhFgbbKwnb9MLmUQDhG6"}` after the player acked `ok`; `{:ok, :web_api}` if the player is not connected or acked `rejected`; `{:error, :unknown}` if no ack arrived. `SpotifyPlayer.command(scope, :pause, fn -> {:ok, :web_api} end)` pauses (toggle) only when the last snapshot says `playing`.
6. Start a listening session from the dashboard: tracks should start on the desktop player.
7. Account page (`/users/account`, API Tokens section): a "Desktop player" row with a Disconnect button appears while enrolled. Clicking it must make the player receive `disconnect: revoked`.
8. Failure checks: kill the player (backend returns to polling), open two instances (the older one gets `replaced`), wait for the access token to expire and reconnect (refresh path).

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| Authorize page: "Invalid client_id or redirect_uri" | Redirect URI not `http://127.0.0.1:<port>/cb`, or the migrations did not run |
| `invalid_scope` on authorize | Any scope other than `player` was requested |
| Token endpoint `invalid_grant` | Code reused or older than 60 s, wrong `code_verifier`, or an already rotated refresh token |
| WebSocket upgrade rejected | Missing or expired `X-Access-Token`, wrong scope, revoked token |
| Join `forbidden` | Topic is neither `desktop:me` nor the authenticated user's id |
| Join `unsupported_protocol` | `proto` missing or not `1` |
| Backend stays in api mode after join | No valid snapshot within 5 s (check `seq`, required keys, value types) |
| Channel closes by itself | Invalid payloads (10 in 60 s) or more than 20 snapshots per second |
