# ADR 0001: Remote control through an Elixir SaaS backend (Phoenix Channels)

- **Status:** Accepted and implemented in this repository (scope clarified in section 0; the backend's contract overrides sections 4, 5 and 13 where they differ, see Amendment 1 at the end)
- **Date:** 2026-10-12
- **Deciders:** Maxime
- **Audience:** the agent(s) implementing this. Read `AGENTS.md` and `docs/architecture.md` first; they describe the existing player and how to build and test it (cross-compiled from WSL, tests run as a Windows exe).

## 0. Scope and normativity (read this first)

**The backend already exists and runs in production, together with a player that connects to its API.** This ADR is therefore implemented **in this repository (the Rust player) only**. Nothing here asks you to build or modify the backend.

| Part | Status | Meaning |
|---|---|---|
| Sections 1, 2 (player side), 6, 6.4, 7 (player rows), 8 (Rust tests), 9 (player tasks), 10 (player items) | **Normative** | Implement and verify these. |
| Section 4 (wire protocol) | **Informative** | A proposed protocol that expresses the intended semantics. The production protocol may differ in event names, payload shapes, auth, enrollment and versioning. |
| Section 5 (backend design) and backend tasks 1a-1e | **Informative** | Documents the reasoning and what the player may assume. **Do not implement.** |
| Section 13 (authentication and authorization) | 13.1 **observed facts** (read from the production backend source); 13.2-13.8 **normative for the player**; 13.9 **requests to the backend**, informative here | Supersedes the pairing-code enrollment in 5.3 and the `X-Device-Token` header in 4.1. |
| Section 14 (coexistence with the Web API) | 14.1, 14.2, 14.4 **informative** (backend routing); 14.3 **normative for the player** (ack truthfulness) | |
| `protocol/` fixtures (section 3) | **Never created** | The backend guide replaced them; the protocol tests use the guide's own examples. |

**The update document has arrived** (2026-10-12): the backend repository's `docs/guides/desktop-player.md`. Its wire protocol, enrollment and backend behaviour are authoritative; see Amendment 1 at the end of this file. Sections 4 and 5 and the pairing-code parts of 13 are kept for context and for the reasoning they record.

Consequences for the implementer:

1. **Isolate everything protocol-specific.** All knowledge of event names, JSON shapes, auth headers, URL paths and the enrollment call must live in `protocol.rs`, `enroll.rs` and `credentials.rs` only. The state machine (`session.rs`), the supervisor, the worker changes and the UI must depend on neutral internal types (`Inbound::Command`, `Outbound::Snapshot`, `Outbound::Ack`, `SessionEvent`) and not on wire details. Changing the protocol must then touch those three files and their tests, nothing else.
2. **Protocol assumptions stay visible.** Mark every guess about the backend with a `// PROTOCOL-ASSUMPTION:` comment; the one that remains is the track `uri` in `src/identity.rs` (Amendment 1).
3. **Test against fakes first.** Protocol and connection code is tested against fake servers and a local WebSocket server; the real backend is exercised by the guide's end-to-end steps.
4. **Player-side behaviour in sections 4.3 and 6.4 is the contract we need from the player regardless of wire format:** at-most-once execution, id-based dedup, relative expiry, re-validation of every remote command, jittered backoff, heartbeat/liveness, bounded queues, offline-first, secrets handling. Keep these even if the production protocol expresses them differently; if the production protocol makes one impossible, report it instead of dropping it silently.

## 1. Context

The player (Rust, GPUI, Windows) reads and controls the local Spotify desktop app. It works standalone. We want it to also act as an **IoT device of a SaaS backend written in Elixir, deployed on the internet**:

- The player **connects out** to the backend (it sits behind NAT; the backend never dials in).
- While connected, the player sends its **snapshot every second**.
- While connected, the backend can send **commands** (play/pause, next, previous, set volume, play a track).
- Everything keeps working locally when the backend is unreachable.

Non-negotiable quality bar: **the implementation must be as resilient and stable as an OTP system.** Concretely this ADR treats "let it crash, supervise, isolate, bound everything, never block, always recover" as requirements for the Rust client as well as the Elixir backend (see section 7).

## 2. Decision

Use **Phoenix Channels over a secure WebSocket**, one persistent connection per player, with the player as the client.

- Backend (**informative; already exists in production**, see section 0): a Phoenix application. One `DeviceChannel` process per connection, one `Device` GenServer per device holding live state and pending commands, `Phoenix.PubSub` as the bus, `Phoenix.Presence` for online status, a LiveView page as the first consumer.
- Player: a new `remote` subsystem in the Rust app, running on its own supervised thread, speaking the Phoenix v2 JSON protocol. It reuses the existing `Command` channel and `Snapshot` shared state; the local UI path is unchanged.
- Delivery semantics for commands: **at-most-once, short expiry, no offline queue.**

### Alternatives considered (rejected)


| Alternative | Why not |
|---|---|
| MQTT + external broker | Second stateful system to run; presence, fan-out and per-device logic leave Elixir. Revisit only for very large or constrained fleets. |
| gRPC bidirectional streaming | `grpc-elixir` is less mature; no Presence/PubSub equivalents; HTTP/2 streams suffer behind some proxies. |
| Plain HTTP POST + SSE | Two channels per device, one request per second, higher command latency. Acceptable only as a future fallback transport. |
| Player as an Erlang distribution node (incl. AtomVM, `erl_dist`) | Cookie-only auth gives full RPC both ways (code execution on backend or on every user's PC); full-mesh model does not scale to consumer devices; needs epmd/dynamic ports through NAT; AtomVM has no Windows port. |
| Elixir in WebAssembly inside the app | No WASI target for AtomVM, needs a JS engine; adds nothing for networking. |

## 3. Repository layout

The backend lives elsewhere (it already exists). In this repository add only:

```
protocol/                (never created: see the backend guide, `docs/guides/desktop-player.md` there)
  README.md              States that it is provisional and lists the PROTOCOL-ASSUMPTIONs
  schemas/*.json         JSON Schema per payload
  fixtures/*.json        Golden messages used by the Rust tests
src/remote/              New Rust subsystem (see section 6)
docs/adr/                This file
```

Existing `src/player.rs`, `smtc.rs`, `volume.rs`, `main.rs` stay, with the changes listed in section 6.3.

## 4. Wire protocol (version 1) (INFORMATIVE, superseded where it differs)

> The backend guide is the contract now (Amendment 1). Differences: topic `desktop:me`, URL `/player/websocket`, no `X-Device-Id`, snapshot carries `uri`.

> **Informative only.** The production backend and player already define a protocol; this section states the intended semantics and a concrete proposal that fits them. Implement it only behind the isolation boundary of section 0 and replace it with the update document's protocol when received. The *semantic rules* in 4.3 remain requirements on the player.

### 4.1 Transport

- URL: `wss://<host>/device/websocket?vsn=2.0.0`. **TLS only**; the client must refuse `ws://` unless an explicit `PLAYER_HUB_INSECURE=1` dev override is set (and never in release builds).
- Serializer: `Phoenix.Socket.V2.JSONSerializer`. Every frame is a JSON array `[join_ref, ref, topic, event, payload]`.
- Auth headers on the upgrade request (not in the URL, so they stay out of access logs): `X-Device-Id: <uuid>` and `X-Access-Token: <OAuth access token>` (see section 13; Phoenix's `connect_info: [:x_headers]` only exposes `x-*` headers, which is why the standard `Authorization` header is not used).
- Topic: `device:<device_id>`. The channel must only accept a join if `<device_id>` equals the id authenticated on the socket.
- Heartbeat: client sends the standard Phoenix `["null", ref, "phoenix", "heartbeat", {}]` every **25 s**. The server's websocket idle `timeout` is **45 s**. Max frame size **64 KiB** on both sides.

### 4.2 Events

Device to server:

| Event | Payload | Notes |
|---|---|---|
| `phx_join` | `{"proto": 1, "app_version": "0.1.0", "session_id": "<uuid, new per process start>"}` | Server replies `ok` with `{"snapshot_interval_ms": 1000, "server_time_ms": <int>}` or `error` with `{"reason": "unsupported_protocol"|"forbidden"|"revoked"}`. |
| `snapshot` | `{"seq": <int>, "snapshot": {...}}` | Sent right after join, then every `snapshot_interval_ms`. `seq` increases by 1 per message per connection; the server drops `seq <= last`. |
| `ack` | `{"command_id": "<uuid>", "status": "ok"|"error"|"rejected"|"expired"|"duplicate", "error": "<string, optional>"}` | Exactly one per received command. |

Server to device:

| Event | Payload | Notes |
|---|---|---|
| `command` | `{"id": "<uuid>", "type": "<see below>", "args": {...}, "ttl_ms": <int>}` | `ttl_ms` is **relative** (the device starts its own timer on receipt); this avoids clock-skew bugs. |
| `config` | `{"snapshot_interval_ms": <int>}` | Lets the backend shed load. Device clamps to 500..30000. |
| `disconnect` | `{"reason": "replaced"|"revoked"|"shutdown"}` | Followed by the server closing the socket. |

Command types and args:

| `type` | `args` |
|---|---|
| `toggle_play_pause`, `next`, `previous` | `{}` |
| `set_volume` | `{"volume": <number 0.0..1.0>}` |
| `play_uri` | `{"uri": "spotify:track:<22 alphanumeric chars>"}` |

Snapshot object (all keys always present):

```json
{
  "running": true,
  "playback": "playing",
  "title": "…", "artist": "…", "album": "…",
  "position_ms": 12345, "length_ms": 215000,
  "volume": 0.5,
  "error": null
}
```

`playback` is `playing|paused|stopped`; `volume` is a number or `null`; `error` is a string or `null`. Strings are truncated to 512 chars by the device and validated (type + length) by the server. Unknown keys are ignored (forward compatibility); unknown events are ignored by both sides.

### 4.3 Rules

- **At-most-once execution.** A command that was delivered but not acked when the connection drops is **never** re-sent; the server marks it `failed` (`disconnected`). Toggle/next/previous are not idempotent, so blind retry is wrong.
- **Expiry.** Default `ttl_ms` is 10 000. The device discards a command whose timer elapsed before it started executing and acks `expired`. The server expires unacked commands after `ttl_ms + 2000`.
- **Idempotency by id.** The device remembers the last 256 command ids with their results. A repeated id gets an `ack` of `duplicate` carrying the original result, and is not executed again.
- **Defence in depth.** The device **re-validates every remote command** (type allow-list, `volume` range, `parse_track_uri` for `play_uri`) and answers `rejected` on failure. It must never pass a remote string to a shell or to a process other than through the existing validated path. The server validates too.
- **One connection per device.** A new successful join for a device kicks the previous connection with `disconnect: replaced`.

## 5. Backend design (Elixir) (INFORMATIVE, do not implement, superseded where it differs)

> **Informative only.** The backend is already deployed. This section records the reasoning and the assumptions the player makes about it (one connection per device, command expiry, per-device auth and revocation, load shedding via `config`, at-most-once command delivery). Use it to understand why the player behaves as specified in section 6; do not build any of it.

Use current stable Elixir/OTP and Phoenix; pin versions in `mix.exs`/`.tool-versions`. Postgres via Ecto.

### 5.1 Supervision tree

```
PlayerHub.Application (one_for_one)
├── PlayerHub.Repo
├── PlayerHubWeb.Telemetry
├── {Phoenix.PubSub, name: PlayerHub.PubSub}
├── PlayerHubWeb.Presence
├── {Registry, keys: :unique, name: PlayerHub.Device.Registry}
├── {DynamicSupervisor, name: PlayerHub.Device.Supervisor, strategy: :one_for_one}
├── {Task.Supervisor, name: PlayerHub.TaskSupervisor}
└── PlayerHubWeb.Endpoint            # last: starts accepting traffic only when everything above is up
```

Rules: no process is started outside this tree; no `spawn`/unsupervised `Task.start`. Fire-and-forget work uses `Task.Supervisor.start_child/2`.

### 5.2 Modules

- `PlayerHubWeb.DeviceSocket`: `connect/3` reads `x_headers`, loads the device, compares the token hash with `Plug.Crypto.secure_compare/2`, rejects revoked devices, assigns `device_id`. `id/1` returns `"device_socket:#{device_id}"` so `PlayerHubWeb.Endpoint.broadcast(id, "disconnect", %{})` can kick or revoke a live connection. Rate-limit failed auth per IP.
- `PlayerHubWeb.DeviceChannel`: `join/3` checks topic id equals the socket's device id, checks `proto`, calls `PlayerHub.Device.attach(device_id, self(), meta)`, tracks Presence in `handle_info(:after_join, …)`. `handle_in("snapshot", …)` validates (schemaless Ecto changeset or hand-written), drops stale `seq`, casts to the Device process. `handle_in("ack", …)` forwards to the Device. `handle_info({:command, payload}, socket)` does `push(socket, "command", payload)`. Handlers must be O(1) and never call into the database.
- `PlayerHub.Device` (GenServer, `restart: :transient`, registered via `{:via, Registry, {PlayerHub.Device.Registry, device_id}}`, started on demand by `PlayerHub.Devices.ensure_started/1`):
  - State: `channel_pid`, monitor ref, `last_snapshot`, `last_seq`, `pending :: %{command_id => %{type, expires_ref, from_pid?}}`, token-bucket for commands.
  - `attach/3`: demonitor the old channel, kick it (`disconnect: replaced`), monitor the new one, fail all pending with `:disconnected`.
  - `handle_info({:DOWN, …})` for the channel: mark offline, fail pending, schedule an idle stop (5 min with no connection, then `{:stop, :normal, state}`).
  - Snapshot handling stores only the **latest** snapshot (never an unbounded queue) and broadcasts `{:snapshot, device_id, snapshot}` on topic `"device:#{device_id}"`.
  - `send_command/3`: refuses with `{:error, :offline | :rate_limited | :invalid}`; creates the command id, persists a `commands` row (`pending`), sends `{:command, payload}` to the channel pid, arms an expiry timer. Returns `{:ok, command_id}` immediately.
  - Command lifecycle `pending → sent → acked | failed | expired`. Every transition broadcasts `{:command_result, device_id, command_id, status}` on the device topic and updates the row through `Task.Supervisor` (DB hiccups must not stall the Device process).
- `PlayerHub.Devices` (context, the only public API for the rest of the app): `send_command/3`, `latest_snapshot/1`, `online?/1`, `register_device/2`, `revoke_device/1`, `list_devices/1`. Callers must not know about processes, so a later move to multi-node (Horde or `:global` for the registry) changes one module.
- Ecto schemas: `devices` (`id` uuid, `owner_id`, `name`, `last_seen_at`, `revoked_at`, timestamps; authentication is OAuth, see section 13, so no `token_hash` or pairing codes), `commands` (`id` uuid, `device_id`, `type`, `args` map, `status`, `error`, `inserted_at`, `sent_at`, `acked_at`).
- **Never persist snapshots per second.** If history is wanted later, sample into a batch writer (track change, or every 30 s); out of scope here.

### 5.3 Enrollment

**Superseded by section 13.** The pairing-code flow originally proposed here is replaced by OAuth 2.1 authorization code + PKCE against the backend's existing Boruta server.

### 5.4 First consumer: LiveView

`/devices/:id` (authenticated, owner only): subscribes to `"device:#{id}"`, shows online state (Presence), the latest snapshot, and buttons that call `Devices.send_command/3`; shows command results as they arrive. It exists to prove the loop end to end and as the reference consumer of the context API.

### 5.5 Backend resilience requirements

- Every `GenServer.call` has an explicit timeout and the caller handles `:exit`.
- No unbounded mailboxes: snapshots overwrite state; a channel whose `message_queue_len` exceeds a threshold (default 500) is disconnected (slow consumer).
- Snapshots arriving faster than 5/s are dropped; more than 20/s disconnects the device. Invalid payloads are counted and 10 in 60 s disconnects.
- A crash of a `Device` process loses only live state; the next snapshot (≤1 s) restores it and pending commands are failed to their callers (`{:command_result, …, :failed}` with `device_restarted`). A crash of a channel makes the player reconnect. Nothing else is affected.
- Graceful deploys: configure Phoenix's socket drainer so connections are closed in batches on shutdown (verify the option names for the Phoenix version used); the client's jittered backoff absorbs the reconnect wave.
- Telemetry events (and a LiveDashboard page) for: connected devices, snapshots/s, command latency (send to ack), ack outcomes, auth failures, Device restarts, kicked slow consumers.

## 6. Player design (Rust) (NORMATIVE)

Protocol-specific parts (`protocol.rs`, `enroll.rs`, `credentials.rs` key names, URL and header details) follow the informative section 4 until the update document replaces it. Everything else in this section is fixed.

### 6.1 Threads

```
UI thread ──Request(Local)───────▶┐
                                  ├▶ mpsc ▶ player::run (existing worker, now supervised)
remote thread ─Request(Remote)───▶┘                   │ Outcome (id, result)
     ▲   │ reads Arc<Mutex<Snapshot>> every 1 s       ▼
     │   └──────────── sends snapshot, acks ──▶ wss to backend
     └───────────────────────────────────────────── commands from backend
```

The remote subsystem is **blocking and thread-based**, matching the existing code. No async runtime is introduced. One connection thread uses a socket read timeout (200 ms) and, between reads, services timers (snapshot tick, heartbeat, expiries, backoff).

### 6.2 Modules (`src/remote/`)

- `protocol.rs` (pure, no I/O): serde types for all payloads; `encode_frame` / `decode_frame` for the Phoenix v2 array format; `RemoteCommand` to `Command` conversion with validation; `Snapshot` to payload conversion with truncation. Heavily unit-tested against `protocol/fixtures/`.
- `transport.rs`: `trait Transport { fn send(&mut self, frame: &str) -> Result<()>; fn recv(&mut self, timeout: Duration) -> Result<Option<String>>; fn close(&mut self); }` and a `tungstenite` implementation over `rustls` (check that the chosen TLS crate cross-compiles with `cargo xwin`; fall back to the other of `rustls` backends if not). Connect, TLS and write timeouts are mandatory.
- `clock.rs`: `trait Clock { fn now(&self) -> Instant; fn sleep(&self, d: Duration); }` with a fake for tests.
- `session.rs`: the connection state machine, written against `Transport` and `Clock` only, so the whole reconnect/heartbeat/expiry behaviour is testable deterministically:

  ```
  Disconnected --backoff elapsed--> Connecting --ok--> Joining --join ok--> Joined
        ▲                              │ fail              │ error/forbidden     │ close/err/heartbeat timeout
        └──────────────────────────────┴───────────────────┴─────────────────────┘
  Unauthorized (401/403/revoked): retry every 5 min, surface to UI, never tight-loop.
  ```
- `credentials.rs`: read/write `(device_id, refresh_token)` in Windows Credential Manager (`CredReadW` / `CredWriteW` via the `windows` crate, features `Win32_Security_Credentials`). Access tokens stay in memory only. Never log tokens.
- `enroll.rs`: the OAuth client of section 13: PKCE, loopback listener, browser launch, code exchange, refresh, revocation, device registration (`ureq` with rustls, blocking, with timeouts). It exposes a small neutral interface (`access_token() -> Result<…>`, `enroll()`, `forget()`) so `session.rs` never sees OAuth details.
- `mod.rs`: `start(config, snapshot, commands, status) -> Handle`. It **writes** the shared `RemoteStatus` (the type already exists in `src/remote_status.rs`, see R12); it does not own the UI types.

### 6.3 Changes to existing code

1. **Command origin and result.** Wrap commands so the worker can report results:
   `pub struct Request { pub command: Command, pub reply: Option<(CommandId, Sender<Outcome>)> }` (or equivalent). `Outcome { id, result: Result<(), String> }`. UI requests have `reply: None` and behave as today (including the `notice` mechanism).
2. **No poisoned mutexes.** Replace every `lock().unwrap()` on shared state with a helper that recovers (`unwrap_or_else(PoisonError::into_inner)`): the data is a plain value that is always valid.
3. **Supervise the worker.** Add `player::supervise(name, factory, policy)` that runs a worker closure on a thread, catches panics (`catch_unwind` inside, or detects a dead `JoinHandle`), restarts it with backoff, and applies OTP-style restart intensity (default: max 5 restarts in 60 s, then mark the subsystem `Failed` and retry after 5 min; never abort the process). Use it for both `player::run` and the remote subsystem. Note: a restarted backend must be recreated by a factory (it owns no state worth keeping).
4. **UI.** The window footer already shows the connection and exchange status (R12); add an enrollment control ("Connect account" button that starts the browser flow of section 13, disabled once enrolled, plus "Forget this PC"). No other UI changes.
5. **Config.** Remote is **disabled unless** `PLAYER_HUB_URL` (or a settings value written at enrollment) is set. With it unset the app behaves exactly as today.

### 6.4 Player resilience requirements

- **R1 Isolation.** Nothing in the remote subsystem may block, slow or crash the local player or UI. Panics in remote code are contained by the supervisor.
- **R2 Reconnect.** Exponential backoff with **full jitter**: delay = random(0, min(60 s, 1 s × 2^attempt)). Reset the attempt counter only after a connection has been stable for 30 s. This is mandatory to avoid a thundering herd after a backend restart.
- **R3 Liveness.** Heartbeat every 25 s; if no reply within 10 s, drop and reconnect. A server `disconnect` event or a close frame triggers the same path.
- **R4 Bounded everything.** Snapshot outbound slot holds only the latest value; inbound command queue capacity 64 (overflow gets an immediate `rejected` ack with `overloaded`); frame limit 64 KiB; string truncation as in 4.2.
- **R5 Timeouts on all I/O.** Connect 10 s, TLS 10 s, write 5 s, read poll 200 ms, HTTP token/refresh calls 15 s.
- **R6 At-most-once + dedup + expiry** exactly as in 4.3.
- **R7 Offline-first.** Local controls and polling keep working in every remote state. Remote state changes never alter `Snapshot` content or the local `notice`/`error` semantics.
- **R8 Secrets.** Token only in Credential Manager; never in logs, env dumps, panic messages or the URL.
- **R9 Graceful shutdown.** On app exit send a WebSocket close frame (bounded to 1 s) and stop threads by dropping channel senders; no detached thread may outlive the process in a way that blocks exit.
- **R10 Observability.** Add the `tracing` crate; log state transitions, backoff delays, ack outcomes (never payload secrets) to a rolling file in `%LOCALAPPDATA%`. Keep a ring buffer of recent events available for a future "diagnostics" view.
- **R12 Connection and exchange status is always shown.** The remote subsystem keeps an `Arc<Mutex<RemoteStatus>>` (defined in `src/remote_status.rs`, already rendered by the window footer) up to date: the `Link` (`Disabled`, `Connecting`, `Connected`, `Offline{retry_in}`, `Unauthorized`, `Failed(reason)`) and the `Exchange` (number of snapshots sent and when the last one went out, and the last command received with its outcome `Ok|Error|Rejected|Expired|Duplicate` and time). Update it on every state transition, every snapshot sent and every command acked (outcomes must match the ack sent to the backend, 14.3). `retry_in` must count down from the real backoff delay. Locking follows R-poison rules (recover from poisoning). The UI never reads anything else from the remote subsystem.
- **R11 Forward/backward compatibility.** Send `proto: 1`; handle `unsupported_protocol` by entering a `Failed` state with a clear message (no retry storm); ignore unknown events and keys.

## 7. Failure behaviour (acceptance matrix)

Rows marked **(player)** are normative and must be covered by automated Rust tests. Rows marked **(backend)** describe backend behaviour the player relies on; they are informative here and are **not** to be built or tested in this repository (the player tests simulate them with the fake server).

| Failure | Required outcome |
|---|---|
| **(player)** Backend down at startup | Player works locally; status `Offline`, retries with jittered backoff |
| **(player)** Network drops mid-session | Heartbeat timeout or read error within ≤35 s; reconnect; first snapshot ≤1 s after join |
| **(player)** Backend restarts (all devices reconnect) | Reconnects are spread by jitter; no tight loop; no duplicate command execution |
| **(player + backend)** Command in flight when connection drops | Server marks `failed(disconnected)`; device never executes it after reconnect |
| **(player)** Same command delivered twice | Executed once; second ack is `duplicate` |
| **(player)** Command arrives after `ttl_ms` | Not executed; ack `expired` |
| **(player)** Invalid/hostile command (bad URI, volume 7, unknown type) | Not executed; ack `rejected`; app unaffected |
| **(backend)** Device process crashes on the backend | Supervisor restarts it; state restored by next snapshot; callers get `device_restarted` |
| **(backend)** Channel process crashes | Player reconnects; no other device affected |
| **(player)** Token revoked while connected | Server sends `disconnect: revoked`; player enters `Unauthorized`, retries every 5 min, UI shows it |
| **(player)** Two instances with the same credentials | Older connection is kicked (`replaced`); no flapping loop (the kicked client must not instantly reconnect: treat `replaced` as 60 s minimum backoff) |
| **(backend)** Slow/stuck player (backpressure) | Server disconnects it after the queue threshold; others unaffected |
| **(player)** Panic inside remote thread or `player::run` | Supervisor restarts it within backoff; UI stays alive; after repeated failures marked `Failed`, retried later |
| **(player)** Mutex poisoned by a panic | Subsequent locks still succeed |
| **(player)** Backend sends an oversized or malformed frame | Frame dropped / connection reset; no panic |

## 8. Testing strategy

Work test-first (see the project's TDD convention).

**Contract tests (player side).** The protocol tests in `src/remote/protocol/tests.rs` use the examples of the backend guide (join, snapshot, command, ack, disconnect). No `protocol/` fixture folder was needed.

**Elixir (informative, out of scope here: the backend already exists and has its own tests).** For reference only, the backend test plan would be:
- `Phoenix.ChannelTest` for join (accept/forbidden/wrong topic/bad proto), snapshot (valid, stale `seq`, invalid, flood), ack handling, kick on re-join.
- `PlayerHub.Device` unit tests: command lifecycle, expiry via short TTL, offline refusal, rate limit, channel `:DOWN` handling, idle stop.
- `Phoenix.LiveViewTest` for the device page.
- Property tests (StreamData) for snapshot/command validation: arbitrary maps never crash the channel.
- Chaos tests: kill the Device process mid-command, kill the channel, assert recovery and that no process or monitor leaks (compare `Registry`/process counts before and after).
- A load smoke test: N (≥1000) simulated devices via `Phoenix.ChannelTest`-style clients or a small `Mint.WebSocket` script sending 1 snapshot/s; record memory and scheduler utilisation.

**Rust** (unit tests run as a cross-compiled Windows exe, see `docs/architecture.md`; keep `remote` code platform-independent where possible):
- `protocol.rs`: golden-frame encode/decode, fixture validation, truncation, command validation.
- `session.rs` with a fake `Transport` and fake `Clock`: backoff schedule (assert the jitter bounds, using an injectable RNG), heartbeat timeout, rejoin and immediate snapshot, dedup window, expiry using the relative TTL, `replaced`/`revoked` handling, overflow behaviour.
- `supervise`: a worker that panics N times is restarted per policy, then marked `Failed`; a worker that runs stably resets the counter.
- Poisoned-mutex test.
- One integration test against a local in-process WebSocket server (tungstenite) simulating Phoenix replies, including mid-stream disconnects.

**End to end (deferred).** No end-to-end test against the production backend until the update document is received and applied. Until then, drive the player against the in-process fake server and verify local effects with the real Spotify (commands executed, snapshots produced).

## 9. Work breakdown

Only the player tasks (2a-2d, 3) and the provisional contract (0) are in scope. Tasks 1a-1e are **informative: the backend exists, do not implement them.**

| # | Task | Done when |
|---|---|---|
| 0 | ~~Provisional `protocol/` schemas and fixtures~~ | Not needed: the backend guide is the contract |
| 1a (informative, skip) | Phoenix app skeleton, supervision tree, Repo/migrations | `mix test` green, app boots, Telemetry wired |
| 1b (informative, skip) | `DeviceSocket` + `DeviceChannel` + Presence | Channel tests and fixtures green |
| 1c (informative, skip) | `Device` GenServer + `Devices` context + command lifecycle | Unit + chaos tests green |
| 1d (informative, skip) | Device registration, owner checks, revocation (see 13.9) | Owner-only and revocation behaviour tested |
| 1e (informative, skip) | LiveView device page | LiveView tests green |
| 2a | Rust: `Request/Outcome`, poison-safe locks, `supervise`, SMTC `bool` results turned into errors (14.3) (+ tests) | Existing 13 tests still green, new tests green, app behaves as before |
| 2b | Rust: `protocol.rs`, `session.rs`, fakes (+ tests) | Failure matrix rows covered |
| 2c | Rust: real `Transport`, `credentials.rs`, `enroll.rs`, `mod.rs` wiring | Integration test with local WS server green; cross-build succeeds |
| 2d | Rust UI: status line + enrollment control | Verified by running the app |
| 3 | Hardening: all (player) failure-matrix rows, runbook for the fake-server setup, update `docs/architecture.md` and `AGENTS.md` | Section 10 satisfied |

## 10. Definition of done

Scope: this repository (the player) only.

- All **(player)** rows of the failure matrix have passing automated tests; the provisional contract fixtures pass.
- With `PLAYER_HUB_URL` unset, the app is behaviourally unchanged (existing tests untouched and green).
- Against the in-process fake server: the player enrolls (or is given credentials), connects, sends snapshots about once a second, executes each command type, acks correctly, and recovers by itself from server restarts and dropped connections without a reconnect storm (assert on the backoff schedule).
- All protocol-specific code is confined to `protocol.rs`, `enroll.rs` and `credentials.rs`; a grep for wire event names outside them finds nothing.
- Every protocol guess is marked `// PROTOCOL-ASSUMPTION:` and listed.
- `docs/architecture.md` and `AGENTS.md` describe the remote subsystem. This ADR stays as the decision record; amend it with the update document, do not rewrite history.
- **Not part of done:** end-to-end tests against the production backend. That happens only after the update document is received and applied.

## 11. Decisions taken by default (change them by amending this ADR)

- (Backend, informative) Single-region, single backend node for v1. The `Devices` context hides process placement so clustering (Horde or `:global`) is a later, contained change; nothing in v1 may depend on a node-local assumption outside that module.
- (Backend, informative) Multi-user model is minimal: each device has one owner; dashboard auth via `phx.gen.auth`.
- No offline command queue; commands expire after 10 s.
- Snapshots are sent every second as originally requested; the server may slow clients with `config`. Sending only on change plus a lighter heartbeat is a deferred optimisation.
- Tracks only for `play_uri` (albums/playlists are out of scope).
- No snapshot history is stored.

## 12. Risks and open questions

- **Phoenix client in Rust is hand-written.** Mitigated by the pure `protocol.rs`, contract fixtures and the in-process server test. Verify behaviour against the real backend once the update document allows it (see section 0).
- **Protocol drift.** The production protocol may differ from section 4. Mitigated by the isolation boundary and the PROTOCOL-ASSUMPTION list; the update document is the authority.
- **TLS crate and `cargo xwin`.** Confirm the TLS backend compiles for `x86_64-pc-windows-msvc` from Linux before building on it (`rustls` with `ring` needs the already-installed clang; confirm).
- **`?autoplay=true` is undocumented Spotify behaviour.** Remote `play_uri` inherits that risk; failure shows as a command that is acked `ok` while nothing plays. Consider verifying via the next snapshot and reporting a mismatch.
- Open: hosting constraints of the production backend (WebSocket idle timeouts, proxy limits) that could change heartbeat or timeout values; the update document should state them.

## 13. Authentication and authorization

> Implemented as written in 13.3 to 13.8 (OAuth 2.1 authorization code with PKCE and a loopback redirect, scope `player`, refresh token in the Credential Manager), except that the backend has no device registration: the access token identifies the user (Amendment 1).

Users log in to the backend with **Twitch OAuth** and may additionally connect **Spotify OAuth**. This section defines how the *player* authenticates and what it may do. The two provider logins are unrelated to the player's credentials; see 13.2.

### 13.1 What the production backend does today (observed)

Read from the backend source (`../premiere-ecoute`, commit `70563994`, on 2026-10-12). Re-verify against the update document.

- **User login:** Twitch (and Spotify linking) through `AuthController` (`/auth/:provider`, `/auth/:provider/callback`); the result is a browser session backed by `user_tokens` rows (`session` context, 14-day validity).
- **Personal API tokens:** generated by the user on the account page (`user_tokens`, context `api`), sent as `Authorization: Bearer`, checked by `Plugs.ApiAuth` for `/api/*`. They have **no expiry** and carry **the user's full API powers**. The lookup in `Token.get_user_by_api_token/1` compares the raw decoded token, so they appear to be stored unhashed (verify). The Stream Deck plugin uses them, pasted by hand.
- **An OAuth 2.1 authorization server already exists (Boruta):** `GET/POST /oauth/authorize` (browser session + CSRF-protected consent screen, PKCE), `POST /oauth/token`, `/oauth/revoke`, `/oauth/introspect`, `POST /oauth/register` (RFC 7591 dynamic client registration; "none"-auth public clients get PKCE), discovery at `/.well-known/oauth-authorization-server` (grants `authorization_code` and `refresh_token`, `S256` only, `scopes_supported: ["mcp"]`). It was built for the claude.ai MCP connector; bearer validation lives in `Mcp.Server.by_bearer_token/1` (`AccessToken.authorize(value: token)`, `sub` = user id).
- **WebSocket:** `UserSocket` at `/socket` performs **no authentication** in `connect/3` (it assigns a random UUID); channels `session:*` and `sessions:lobby` are open.
- **Impersonation:** admins can impersonate a user; `Accounts.Scope` carries `impersonating?: true` and the real `admin`.

Findings that affect this design:

| # | Finding | Consequence |
|---|---|---|
| F1 | The MCP bearer path calls `AccessToken.authorize(value: token)` without checking the token's scope | Any valid Boruta token for any scope would be accepted by `/mcp`. A new `player` scope would let a player token call MCP. **Must be fixed on the backend before issuing player tokens.** |
| F2 | Personal API tokens are long-lived, unscoped, and (apparently) unhashed | Not suitable for the player: a leaked device credential must not equal full account access. |
| F3 | `UserSocket` is anonymous | The player needs a separate, authenticated socket. Do not extend `UserSocket`. |
| F4 | Boruta matches `redirect_uri` against the client's registered URIs by exact match, except that a `*` in a registered URI matches one DNS-label-like token (`[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]`, 3-63 characters; `deps/boruta/lib/boruta/oauth/schemas/client.ex`). It has no native RFC 8252 loopback-port rule | Registering `http://127.0.0.1:*/cb` would accept any 4-5 digit port, but only by accident of that pattern; see 13.4. |
| F5 | Boruta **rotates refresh tokens**: a refresh creates a new token and revokes the previous refresh token immediately, with no grace window (`deps/boruta/lib/boruta/oauth/authorization.ex`). Maximum lifetimes in the library config: access token 24 h, refresh token 30 days | A crash after the server rotated but before the player stored the new token loses the credential (13.5). A PC left off for more than 30 days must log in again. |

### 13.2 Principles

1. **Three independent credentials, never mixed:** the user's *login* (Twitch session in the browser), the backend's *Spotify OAuth* tokens (server-side only, for backend features that call the Spotify Web API), and the player's *own OAuth tokens*. The player never receives, stores or forwards Twitch or Spotify tokens; its local Spotify control needs none.
2. **Least privilege.** The player's token carries only the scope `player`: register/identify a device and use the device socket. It must not work on `/api/*` or `/mcp`.
3. **Owner only.** A device can only be controlled by the account that enrolled it (13.6).
4. **Revocable at any time**, per device, taking effect on live connections.
5. **Standards over invention:** reuse the existing OAuth 2.1 server (authorization code + PKCE, refresh tokens, revocation) rather than a bespoke pairing scheme.

### 13.3 Decision

The player is a **public OAuth client** (no secret) using **authorization code + PKCE (S256) with a loopback redirect** (RFC 8252, RFC 7636) against the existing Boruta server, with scope `player` and refresh tokens.

| Option | Verdict |
|---|---|
| Paste a personal API token (as the Stream Deck plugin does) | Rejected: over-privileged, non-expiring, copy-paste (F2). Not offered even as a fallback in release builds. |
| Typed pairing code (original 5.3) | Replaced: custom protocol, no refresh/revocation story, duplicates what Boruta provides. |
| Per-install dynamic client registration | Rejected: open registration would create an unbounded number of clients. Use **one pre-registered public client** whose `client_id` ships in the app (a public identifier, not a secret). |
| Device authorization grant (RFC 8628) | Not available in the current server; keep as a possible future fallback for headless machines. |
| Authorization code + PKCE, loopback | **Chosen.** The user is already logged in with Twitch in the browser; the flow reuses the existing login and consent screen. |

### 13.4 Enrollment flow

```
Player                       Browser                         Backend (Boruta)         Twitch
  │ verifier (CSPRNG), challenge=S256(verifier), state; listen on 127.0.0.1:<port>
  │ open browser ─────────────▶ GET /oauth/authorize?response_type=code&client_id=<player client>
  │                            │   &redirect_uri=http://127.0.0.1:<port>/cb&scope=player
  │                            │   &code_challenge=…&code_challenge_method=S256&state=…
  │                            │────────────────────────────▶│ not logged in? ─────▶ Twitch login (existing)
  │                            │◀────────────────────────────│◀───────────────────── (existing session created)
  │                            │ consent: "Premiere Ecoute Player wants to connect this PC to your account" [Approve]
  │ ◀─ redirect 127.0.0.1:<port>/cb?code=…&state=… ──────────│
  │ verify state; POST /oauth/token {grant_type=authorization_code, code, code_verifier, client_id, redirect_uri}
  │ ◀──────────────────────────────── {access_token, refresh_token, expires_in}
  │ POST /api/player/devices {name} with Bearer access token ──▶ {device_id}      (13.9, new)
  │ store (device_id, refresh_token) in Credential Manager; open the device socket
```

- **Redirect strategy (F4).** Two workable options, backend's choice, stated in the update document: (a) register `http://127.0.0.1:*/cb`, which works today because `*` matches a 3-63 character alphanumeric token and ports are 4-5 digits (it is an accident of Boruta's pattern, so pin it with a backend test); or (b) register a small fixed list of ports (for example five) and have the player try them in order, failing with a clear message if all are busy. The player supports both: it tries ephemeral ports unless the configuration lists fixed ones. No custom URI scheme.
- The consent screen already exists; it needs readable text for the `player` scope (13.9).
- The user can have several PCs: each enrollment creates its own tokens and its own `device_id`.

### 13.5 Token lifecycle and the socket

- **Storage:** `refresh_token` and `device_id` in Windows Credential Manager (per-user DPAPI protection). The `access_token` lives in memory only.
- **Refresh:** use `grant_type=refresh_token` when the access token has under 60 s left, and once on any `401`. Boruta rotates refresh tokens (F5), so every successful refresh returns a new one that **must** be persisted. Write the new refresh token to the Credential Manager *before* using the new access token, with an atomic replace, and never refresh from two threads at once (one mutex-protected refresh path). A crash in the window between the server's rotation and the local write still loses the credential; that case is accepted and recovered by a browser re-login (one click), unless the backend adds a short grace window (13.9 item 3). `invalid_grant` means the credential is dead: enter `Unauthorized` (no retry loop), and show "Reconnect your account" in the UI.
- **Connecting:** the upgrade request carries `X-Access-Token` and `X-Device-Id`. The server authenticates the token, finds the user, loads the device, and requires `device.owner_id == user.id`.
- **Live connections and expiry:** authentication happens at connect time; an open socket is **not** closed merely because the access token expired. Revocation is enforced two ways: immediately by broadcasting `disconnect` on the socket id (`device_socket:<device_id>`) when a device or token is revoked, and by a server-side re-check every 5 minutes as a safety net. A reconnecting player always refreshes first (the access token is short-lived).
- Tokens go in headers and request bodies, never in URLs, query strings or logs.

### 13.6 Authorization: only the owner controls a device

Enforced at every layer, never only at one:

1. **Socket connect:** the token's `sub` must be the device's `owner_id`.
2. **Channel join:** a device channel accepts a join only when the topic's device id equals the authenticated device id.
3. **Command path:** the `Devices` context API takes the caller's `Accounts.Scope` and refuses unless `scope.user.id == device.owner_id`. This check lives in the context, not in controllers or LiveViews, so every caller (LiveView, API, MCP, jobs) gets it.
4. **No delegation:** no sharing, no co-owners, and **no control based on Twitch roles** (moderators, viewers, channel points). Admins may list and revoke devices but not send commands.
5. **Impersonation (decided):** an admin impersonating a user acts with that user's `Scope` (`impersonating?: true`) and **may send device commands** as the owner. Decision recorded by Maxime on 2026-10-12: **no audit log** is required for these commands. Consequence to keep visible: an admin can make a streamer's PC play something without a trace, so this stays limited to admins and the command allow-list of 4.3 remains the safety limit. Adding an audit record later is a backend-only change (the `commands` table already identifies the device and type; it would need an `acting_admin_id`).
6. **Player-side defence in depth stays** (4.3): even an authenticated backend can only trigger the allow-listed, re-validated commands.

### 13.7 Revocation and account lifecycle

- A user revokes a device on the account page, next to the existing API-token list. This deletes the device row, revokes its OAuth tokens (Boruta revocation) and kicks the live socket. The player moves to `Unauthorized`.
- "Forget this PC" in the player calls `POST /oauth/revoke` for its refresh token, then deletes its local credentials.
- Deleting the account, or revoking everything, removes all devices and tokens.
- **Provider logins don't affect devices.** Signing out of Twitch, or the user disconnecting the app on Twitch, ends their browser session but leaves enrolled devices working until revoked. Unlinking Spotify has no effect on the player. (Banning or deleting the account does revoke devices.)

### 13.8 Player implementation requirements (normative)

- **PKCE:** verifier of 64 random characters from a CSPRNG (the `getrandom`/OS RNG), challenge = base64url(SHA-256(verifier)) without padding. Unit-test with the RFC 7636 appendix B vector: verifier `dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk` gives challenge `E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM`.
- **State:** random, single use, compared in constant time.
- **Loopback listener:** `std::net::TcpListener` bound to `127.0.0.1` only; accepts the first request whose path is `/cb` and whose `state` matches, ignoring everything else; request size limit (8 KiB); total timeout 5 minutes; answers a small static "You can close this tab" page; closes immediately afterwards.
- **Browser launch:** only an `https://` URL built from the configured host, through the Windows URL handler (as `play_uri` already does), never through a shell string.
- **HTTP:** HTTPS only, connect/read timeouts, bounded response size, no redirect-following to other hosts. Treat `access_denied` as a normal user cancellation (back to `NotEnrolled`, no error banner).
- **Secrets:** never log codes, verifiers, tokens or full URLs with query strings; redact in panic messages.
- **State in UI:** `NotEnrolled`, `Enrolling`, `Enrolled`, `Unauthorized`; controls: "Connect account" and "Forget this PC". Local playback control works in all states.
- **Tests** (fake authorization server on localhost): successful flow, wrong `state`, `access_denied`, expired/invalid code, refresh success, refresh rotation with a crash between steps (credential never lost), `invalid_grant` leading to `Unauthorized`, listener timeout, a second unrelated request ignored.

### 13.9 Requests to the backend (informative here; to appear in the update document)

1. Pre-register the public client `premiere-ecoute-player` (PKCE required, `authorization_code` + `refresh_token`), and add the scope `player`.
2. **Fix F1:** require the `mcp` scope in the MCP bearer path (and check scope in any other Boruta-token consumer) before any `player` token exists.
3. Choose the loopback redirect option (F4) and test it; optionally add a short grace window for the previous refresh token to remove the crash-window lockout (F5); set explicit access-token (suggested 1 h) and refresh-token (suggested 30 days) TTLs for this client.
4. Add a `devices` table (`id`, `owner_id`, `name`, `last_seen_at`, `revoked_at`), `POST /api/player/devices` (Bearer, scope `player`), and a device list with revoke on the account page.
5. Add an authenticated `PlayerSocket` (separate from `UserSocket`, F3) reading `x_headers`, with `id/1 = "device_socket:<device_id>"`.
6. Make revocation kick live sockets and add the 5-minute re-check.
7. Consent-screen text for the `player` scope and the client name.
8. Apply the existing rate limiting to `/oauth/token` and `/oauth/authorize` for this client.

### 13.10 Threats considered

| Threat | Mitigation |
|---|---|
| Authorization code intercepted by another local program | PKCE: the code is useless without the verifier, which never leaves the player process |
| Another program races the loopback port | Random `state`, one valid request accepted, short lifetime |
| Phishing the consent step | Consent shows client name and plain-language scope; the URL is the backend's own, opened from the app |
| Stolen refresh token (malware running as the same user) | Scope limited to `player`, owner-only authorization, per-device revocation, 5-minute revocation re-check; cannot reach `/api/*` or `/mcp` once F1 is fixed |
| Backend or a staff account misused to drive a player | Owner-only checks (impersonating admins count as the owner, by decision, with no audit log); player re-validates every command |
| Token leaks through logs or URLs | Tokens only in headers and bodies; redaction rules in 13.8 |
| Stale credential after account removal | Deletion revokes devices and tokens; periodic re-check closes live sockets |

### 13.11 Decisions on the former open questions

Decided by Maxime on 2026-10-12, or resolved from the backend source:

- **Scope:** one `player` scope. No read/control split.
- **Impersonation:** an impersonating admin may send commands to the impersonated user's device, without an audit log (see 13.6 item 5).
- **Refresh-token crash window:** accepted. Recovery is a one-click browser re-login. A backend grace window stays optional (13.9 item 3).
- **Spotify Web API vs local player:** the backend prefers the local player when one is online; see section 14.
- Resolved from source: loopback redirect matching (F4) and refresh rotation (F5).

## 14. Coexistence with the backend's Spotify Web API control

**Decision (Maxime, 2026-10-12): prefer the local player.** The backend already controls a streamer's Spotify through the Spotify Web API (for example session next/previous, and the `SpotifyProbe` worker). When the owner has a player online, the backend routes player commands to it instead of the Web API.

This section is **informative for the backend** (it is deployed and will receive the update document) and **normative for the player** only where it constrains acknowledgements (14.3).

### 14.1 Routing rule (backend)

For a command on behalf of user U (play, pause, next, previous, volume, play a track):

1. **Eligible for local routing** if U has a device that is online (Presence) **and** its latest snapshot has `running: true`. A running desktop Spotify that is idle is still the PC's Spotify; whether it is the *active* playback device is not known to the player.
2. If eligible, send the command to the device (section 4).
3. Otherwise use the existing Web API path unchanged.
4. If several devices are eligible, use the one with the most recent snapshot showing `playing`, else the most recently connected. (Multi-PC per user is expected to be rare.)

### 14.2 Fallback rule (backend)

Fall back from the local path to the Web API **only when the local command definitely did not execute**:

| Local outcome | Executed? | Fallback to Web API |
|---|---|---|
| Device offline or rate-limited at send time | no | yes |
| Ack `rejected`, `expired`, or `error` | no (by 14.3) | yes |
| Ack `ok` | yes | no |
| No ack (timeout, disconnect after delivery) | **unknown** | **no**: report failure; a blind retry could double-toggle or skip two tracks |

### 14.3 Player requirements

- An ack of `rejected`, `expired` or `error` **guarantees the action was not performed**; `ok` means it was. The backend's fallback depends on this, so the player must never ack `error` for something that partially executed, and never ack `ok` for something that did not happen.
- **Known gap to close in the implementation:** `smtc.rs` calls `TrySkipNextAsync`, `TrySkipPreviousAsync` and `TryTogglePlayPauseAsync` and ignores the `bool` they return (`false` means Spotify did not accept the command). Today the player reports success anyway. Those methods must turn `false` into `Err`, so an `ok` ack really means accepted. `play_uri` can only confirm that the URL handler was launched, not that Spotify played the track (see section 12); the doc must not claim more.
- The snapshot (`running`, `playback`) is what the backend uses for eligibility (14.1); keep it accurate and fresh (about 1 s).

### 14.4 Open caveats (for the update document)

- **Which device is active.** The Web API controls whichever Spotify device is active (phone, speaker, another PC). The local player controls this PC's Spotify. If the streamer plays on another device while the PC's Spotify is merely running, local routing sends the command to the wrong place. The backend can compare the Web API's active device with the player's `running`/`playing` state before choosing, at the cost of an extra API call; whether to do that is a backend decision.
- **Session state.** The backend's session logic (current track, `PlaybackState`) currently follows Web API playback. Commands sent locally change playback outside that path; the backend must refresh its state from the next snapshot or Web API poll so the two do not drift.
- **`SpotifyProbe`** checks that the Web API accepts player commands. It stays as is; it validates the fallback path.

## Amendment 1 (2026-10-12): the backend's contract is now the authority

The backend repository ships `docs/guides/desktop-player.md` ("Desktop player hand-off"). It supersedes sections 4, 5 and 13 of this ADR wherever they differ. What changed, and how the player follows it:

| This ADR said | Now (backend guide) | Player |
|---|---|---|
| `X-Device-Id`, `device_id`, `POST /api/player/devices` | Removed: one player per user, the access token identifies the user | No registration step |
| Topic `device:<id>`, URL `/device/websocket` | Topic `desktop:me`, URL `/player/websocket` | `remote/protocol.rs`, `Settings::ws_url` |
| Snapshot without track identity | Snapshot carries `uri` (required key, may be `null`) | `identity.rs`, see below |
| Several devices per user | Exactly one; a new join replaces the previous connection | Handled as `disconnect: replaced` |
| Client id to be registered | Fixed public client `6c1d8f0e-3a52-4b7e-9e41-2f5a7c9d8b13`, scope `player`, redirect `http://127.0.0.1:<port>/cb` | `remote/oauth.rs` |

Unchanged and implemented as written here: the worker design and resilience rules (section 6 and R1 to R12), the failure behaviour of section 7, and section 14 (acks are truthful: `error`, `rejected` and `expired` mean nothing was done). Section 13.9 (requests to the backend) is fulfilled by the guide.

### Where the player had to decide

- **Track `uri`.** Windows media controls do not expose Spotify's track URI, but the backend detects track changes by comparing `uri` (`SpotifyPlayer.handle/2`). The player sends the URI it was last told to play when that command caused the track change, otherwise a synthetic `spotify:local:artist:album:title:seconds` identity that changes exactly when the track changes (`src/identity.rs`). `// PROTOCOL-ASSUMPTION:` the backend accepts any string there and only compares it. Consequence to confirm with the backend: for tracks the player did not start itself, the backend cannot match `uri` to a discography track.
- **Spotify refusing a command.** `TrySkipNextAsync`, `TrySkipPreviousAsync` and `TryTogglePlayPauseAsync` answer `false` when Spotify did not take the command; that is now an error, so an `ok` ack means Spotify accepted it (14.3).
- **Plain `http://`** is accepted only for a server on this PC; anything else must be `https://` (`Settings::parse`).
- **Crash window of refresh rotation** (decision 3 of 13.11): the rotated refresh token is kept in memory before it is written, and the write is retried, so a failing credential store cannot lose it while the app runs.

### Status

Implemented in this repository, with unit tests and real-socket tests: protocol, session state machine, reconnect and backoff, OAuth sign-in with PKCE, token refresh, credential storage in the Windows Credential Manager, the supervised worker, and the window's server band with Connect to server, Sign in and Sign out.

**Verified end to end against the local backend (2026-10-12):** connect, sign in, "Server linked", commands sent by the backend executed on this PC, restart, sign out.

**Not yet verified:** the backend falling back to Web API polling when the player is killed, the older instance receiving `replaced` when a second one starts, and the `uri` assumption above.

Gaps and tidy-ups found along the way, with priorities, are in `docs/refactoring.md`.
