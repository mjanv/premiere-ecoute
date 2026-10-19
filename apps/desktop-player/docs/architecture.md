# Architecture

A Windows desktop app that shows and controls the **local** Spotify desktop app: track info, progress, play/pause, previous/next, Spotify's own volume, and and, when the backend asks, starting a chosen track. It uses no Spotify Web API. Everything goes through Windows APIs that Spotify already exposes to the OS. Optionally it links to a Première Écoute backend (sign in with the user's account, send a snapshot every second, run commands the backend sends); see [The backend link](#the-backend-link).

The UI is written with [GPUI](https://www.gpui.rs/) (Zed's UI framework) through the `gpui-kit` crate. Development happens in WSL2; the app is cross-compiled to a native Windows `.exe`.

Contents: [Overview](#overview), [Threads and data flow](#threads-and-data-flow), [Modules](#modules), [The Windows side](#the-windows-side), [The UI](#the-ui), [The live waveform](#the-live-waveform), [The backend link](#the-backend-link), [Error handling](#error-handling), [Testing](#testing), [Build pipeline](#build-pipeline), [Known limitations](#known-limitations), [Extending](#extending). What to tidy next: [refactoring.md](refactoring.md)

## Overview

```
 main thread (GPUI)                          worker thread
┌───────────────────────┐   Request (mpsc)  ┌───────────────────────────┐
│ NowPlaying (view)     │ ────────────────▶ │ player::run(backend, ...) │
│  render() reads  ◀────┼── Arc<Mutex<      │  loop {                   │
│  the snapshot         │    Snapshot>> ◀───┼─  backend.snapshot()      │
│  timer → cx.notify()  │                   │   → store in the Mutex    │
└───────────────────────┘                   │   recv_timeout(750 ms)    │
                                            │   → apply one Request }   │
                                            └─────────────┬─────────────┘
                                                          │ trait Backend
                                          ┌───────────────┴───────────────┐
                                          │ smtc.rs   media transport     │
                                          │           controls (WinRT)    │
                                          │ volume.rs per-app volume      │
                                          │           (Core Audio / COM)  │
                                          │ rundll32  spotify: URIs       │
                                          └───────────────────────────────┘
```

Three layers:

1. **Core** (`src/player.rs`): platform-independent state, the `Backend` trait, `Command`, `Request` and `Reply`, the worker loop, and pure helper functions.
2. **Backend** (`src/smtc.rs`, `src/volume.rs`, `cfg(windows)` only): the real implementation of `Backend` using Windows APIs.
3. **UI** (`src/ui/`, wired in `src/main.rs`): a GPUI view that renders the latest snapshot and sends commands.

Around them: `src/capture.rs` and `src/waveform.rs` (the live waveform), `src/remote/` (the backend link), `src/identity.rs` (the track URI sent to the backend) and `src/supervise.rs` (restarting crashed workers). Their own sections follow.

## Threads and data flow

### Why a worker thread

The Windows calls block. `IAsyncOperation::join()` waits for a WinRT operation to finish, and the audio session enumeration is a chain of COM calls. If these ran inside `render()` the window would freeze for as long as they take. So a single worker thread owns the `Backend` and performs every call. The UI thread never touches Windows APIs.

The thread is started in `main()` (`src/main.rs`):

```rust
let shared = Arc::new(Mutex::new(Snapshot::default()));
let (commands, rx) = player::channel();
let shared = shared.clone();
std::thread::spawn(move || player::run(smtc::Smtc, rx, shared, POLL));
```

### Worker to UI: a shared snapshot

`Arc<Mutex<Snapshot>>` is shared state. `Arc` is a reference-counted pointer that lets both threads own the same value. `Mutex` ensures only one thread reads or writes it at a time. The worker overwrites the whole `Snapshot` on every poll; `render()` takes the lock, clones the `Snapshot`, and releases the lock at once:

```rust
let snap = lock(&self.shared).clone(); // `lock` recovers from a poisoned mutex
```

Cloning is cheap (a few short strings) and keeps the lock hold time tiny, so the worker is never blocked behind a slow render.

The UI does not get *pushed* updates. GPUI only re-runs `render()` after something calls `cx.notify()`. A task spawned with `cx.spawn` therefore wakes up every `POLL / 3` (250 ms), or every 33 ms while a track plays and the live waveform is moving, and notifies the view. It exits when `this.update(...)` fails, which happens once the view is gone.

### UI to worker: a command channel

`std::sync::mpsc::channel` is a multi-producer, single-consumer queue. The UI holds the `Sender<Request>`, the worker holds the `Receiver`. A click sends a value; nothing blocks:

```rust
let _ = commands.send(Request::local(Command::Next));
```

The result of `send` is ignored on purpose. It fails only when the receiver has been dropped, which means the worker has already exited.

`Command` is a plain enum, and a `Request` wraps it:

```rust
pub enum Command {
    TogglePlayPause,
    Next,
    Previous,
    SetVolume(f32),
    PlayUri(String),
}

pub struct Request {
    pub command: Command,
    pub reply: Option<Sender<Reply>>, // set for commands from the backend: the answer becomes the ack
    pub deadline: Option<Instant>,    // a command that starts after it is not run (`Reply::Expired`)
}
```

Local (UI) requests have no reply: a failure becomes the `notice` in the snapshot. Remote requests carry a deadline and a reply channel; see [The backend link](#the-backend-link).

### The worker loop

`player::run` does two things alternately: refresh the snapshot, then wait for a request. It takes the receiver by reference, so a supervisor can restart it after a panic.

```rust
loop {
    let snapshot = backend.snapshot().unwrap_or_else(Snapshot::failed);
    *lock(&shared) = snapshot;

    match commands.recv_timeout(poll) {
        Ok(request) => { /* expired? run it; reply or set the notice */ }
        Err(RecvTimeoutError::Timeout) => {}
        Err(RecvTimeoutError::Disconnected) => return,
    }
}
```

`recv_timeout(poll)` serves two purposes at once:

- It is the **sleep** between polls (up to 750 ms).
- It **wakes immediately** when a command arrives, so a button press is applied without waiting for the next poll.

After a command runs, the loop goes back to the top and takes a fresh snapshot straight away, so the UI reflects the effect (for example "Pause" turning into "Play") within one render cycle.

When the `Sender` is dropped (window closed, process ending) `recv_timeout` returns `Disconnected` and the loop returns, ending the thread. No explicit shutdown code is needed.

## Modules

### `src/player.rs`

| Item | Role |
|---|---|
| `Playback` | `Playing`, `Paused`, `Stopped` |
| `Snapshot` | Everything the UI renders: `running`, `title`, `artist`, `album`, `playback`, `position`, `length`, `artwork: Option<Artwork>` (cover bytes plus its dominant tint), `volume: Option<f32>`, `error: Option<String>` (player unusable), `notice: Option<String>` (last command failed) |
| `Snapshot::not_running()` / `failed(e)` | Constructors for the two "no data" states |
| `Snapshot::state_label()`, `album_line()`, `progress()`, `can_control()` | Presentation logic kept out of the view so it can be tested |
| `trait Backend` | `snapshot`, `toggle_play_pause`, `next`, `previous`, `set_volume`, `play_uri` |
| `Command`, `Request`, `Reply` | What can be asked; a request adds an optional reply channel and deadline; a reply is `Done`, `Failed` or `Expired` |
| `lock` | Locks shared state and recovers from a poisoned mutex |
| `run`, `channel` | The worker loop and the channel constructor |
| `parse_track_uri`, `autoplay_uri`, `current_position`, `format_time` | Pure helpers (see below) |

`Snapshot` derives `Default`, which gives the "nothing known yet" state shown before the first poll. `volume` is an `Option<f32>` because Spotify may have no audio session yet, and the UI needs to tell "0 %" apart from "unavailable".

### The `Backend` trait

`Backend` is the seam that makes the core testable. It contains no Windows types:

```rust
pub trait Backend {
    fn snapshot(&mut self) -> Result<Snapshot, String>;
    fn toggle_play_pause(&mut self) -> Result<(), String>;
    fn next(&mut self) -> Result<(), String>;
    fn previous(&mut self) -> Result<(), String>;
    fn set_volume(&mut self, volume: f32) -> Result<(), String>;
    fn play_uri(&mut self, uri: &str) -> Result<(), String>;
}
```

`run` is generic over it (`mut backend: impl Backend`), so the compiler generates a version of `run` for each concrete backend, with no dynamic dispatch. Tests pass a `Fake`; the app passes `smtc::Smtc`. Methods take `&mut self` so a backend may keep state (a COM handle, a cache) without interior mutability.

### Pure helpers

- **`parse_track_uri`**: accepts `spotify:track:<id>`, `https://open.spotify.com/track/<id>?si=…`, or `open.spotify.com/intl-xx/track/<id>`, and returns a normalised `spotify:track:<id>`. It requires a 22-character alphanumeric id. Anything else (albums, playlists, garbage) is an `Err`. This validation matters because the string is later passed to a process launcher.
- **`autoplay_uri`**: appends `?autoplay=true` (see [Starting a track](#starting-a-track)).
- **`current_position`**: `reported + elapsed` while playing, clamped to the track length; `reported` unchanged when paused or stopped.
- **`format_time`**: `Duration` to `m:ss`.

## The Windows side

Both backend modules are declared with `#[cfg(windows)]` in `main.rs`. On any other OS they are not compiled, and `main()` falls back to a snapshot saying "only Windows is supported".

### `src/smtc.rs`: System Media Transport Controls

SMTC is the API behind the Windows media flyout and the keyboard media keys. Apps such as Spotify register a "session" with it; any other app can read that session and send it commands. This is why the app needs no Spotify credentials.

`spotify_session()` requests the `GlobalSystemMediaTransportControlsSessionManager`, lists all sessions, and returns the first whose `SourceAppUserModelId` contains `spotify` (case-insensitive). If none matches, Spotify is not running (or has not registered yet).

`snapshot()` reads, from that session:

- `TryGetMediaPropertiesAsync` → title, artist, album
- `GetPlaybackInfo().PlaybackStatus()` → `Playing` / `Paused` / other (mapped to `Stopped`)
- `GetTimelineProperties()` → start, end, position, last-updated time

Control calls are `TryTogglePlayPauseAsync`, `TrySkipNextAsync` and `TrySkipPreviousAsync`.

**How async is handled.** WinRT methods return `IAsyncOperation<T>`. The `windows` crate gives it an inherent `.join()` that blocks the calling thread until the operation completes. That is acceptable only because every call happens on the worker thread. (`.get()`, which older `windows` versions had, no longer exists.)

**Time units.** WinRT `TimeSpan` and `DateTime` are counts of 100 ns ticks. `ticks(...)` converts `TimeSpan` to `Duration` (`ticks * 100` nanoseconds). `DateTime` counts from 1601-01-01, so the code adds 11 644 473 600 s to the Unix time to compare "now" with `LastUpdatedTime`.

**Position extrapolation.** SMTC reports the position *as of the last update*, which Spotify refreshes only on play, pause, seek or track change, not continuously. The progress bar would freeze without correction. `snapshot()` computes `now - LastUpdatedTime` and passes it to `current_position`, which adds it to the reported position while the track is playing.

### `src/volume.rs`: Spotify's own volume

SMTC has no volume control, so this uses the older Core Audio session API, the one behind the per-app sliders in the Windows volume mixer:

1. `CoInitializeEx` (multithreaded) for the current thread. It is called on every request; repeated calls on an initialised thread are harmless.
2. Create an `IMMDeviceEnumerator`, get the default render (output) device.
3. `Activate` an `IAudioSessionManager2` on it and enumerate its sessions.
4. For each session, `cast()` it to `IAudioSessionControl2` to read the process id, then `OpenProcess` + `QueryFullProcessImageNameW` to get the executable path. The session is Spotify's if the path ends in `\spotify.exe`.
5. `cast()` the matching session to `ISimpleAudioVolume` and call `GetMasterVolume` / `SetMasterVolume`.

`cast()` is the Rust form of COM `QueryInterface`: asking an object for one of its other interfaces. The module is `unsafe` throughout because these are raw COM calls with no Rust-level safety guarantees. The unsafe blocks are small and contain only the FFI calls.

Spotify has several processes; only the audio one owns a session. A session appears only after Spotify has produced audio at least once, hence `Option<f32>`: `get()` returns `Ok(None)` and `set()` returns an error explaining that something must play first.

This changes **Spotify's volume only**, the same value as its slider in the mixer. It does not touch the Windows master volume.

### Starting a track

There is no API for "play this track" in the local app. The only local mechanism is the `spotify:` URI scheme registered by the desktop client. `play_uri` hands the URI to the Windows protocol handler:

```rust
std::process::Command::new("rundll32")
    .args(["url.dll,FileProtocolHandler", &autoplay_uri(uri)])
    .creation_flags(CREATE_NO_WINDOW)
    .spawn()
```

`rundll32 url.dll,FileProtocolHandler` is what Windows uses to open a URL with its registered handler. `CREATE_NO_WINDOW` stops a console window from flashing.

A plain `spotify:track:<id>` only opens the track's *album page*. Testing against the running client showed that `?autoplay=true` makes it play:

| URI | Result |
|---|---|
| `spotify:track:<id>` | opens the album page |
| `spotify:track:<id>:play`, `?play=true`, `--uri=…` | no change |
| `spotify:track:<id>?autoplay=true` | starts playing |

The window has no track field any more: `play_uri` is called for commands from the backend. When it succeeds, `identity.rs` remembers the URI so the next track change reports it. This relies on undocumented client behaviour and may change with Spotify updates. The test `autoplay_uri_makes_the_desktop_app_start_the_track` pins the format; the behaviour itself can only be verified against a real client.

## The UI

The window is a single `NowPlaying` view in `src/ui/mod.rs`; `src/main.rs` only wires the shared state, fonts, assets and window options. Design decisions (palette from the cover, type, the minute ruler, the footer) are in [`docs/ui.md`](ui.md).

How it ties into the architecture:

- **State in:** `render()` clones the shared `Snapshot` and the shared `RemoteStatus` (locks recover from poisoning), derives a `Palette` from the cover's tint, and builds the element tree. No Windows API is touched on the UI thread.
- **Commands out:** the transport buttons clone the `Sender<Command>` into `cx.listener` closures and send `Request::local(Command::Previous)`, `TogglePlayPause`, `Next`.
- **Volume slider and the 1.5 s hold:** two writers feed the slider, the user and the poll. A drag emits `SliderEvent::Change`; the subscription records `volume_touched` and sends `SetVolume`. `render()` writes the polled volume into the slider only when the user has not touched it for `VOLUME_HOLD` and the values differ by more than 0.005. `SliderState::set_value` does not emit `Change`, so no feedback loop.
- **Repaint:** GPUI repaints only when notified, so a task spawned with `cx.spawn` calls `cx.notify()` every `POLL / 3`, or every 33 ms while a track plays and the waveform is live.
- **Remote status:** the footer renders `RemoteStatus` (`src/remote_status.rs`): the link state and what was exchanged with the backend. The remote subsystem (ADR 0001) is the only writer.
- **Cover art:** `smtc.rs` reads the SMTC thumbnail once per track change (retrying a few polls, since it arrives late), `Artwork::from_bytes` decodes it and computes the dominant tint, and the view caches the decoded `gpui::Image` by `Artwork::id`.

## The live waveform

A small box under the ruler holds a line that stays in place and moves with Spotify's sound, like an oscilloscope: the actual waveform of the most recent ~25 ms, redrawn about 30 times a second. It is not the waveform of the track (the player never has the track, only what plays now).

- `capture.rs` (Windows): per-process loopback capture of the Spotify process (`ActivateAudioInterfaceAsync` with the process-loopback parameters, Windows 10 2004 or newer). Only Spotify's own audio, never other apps, and no microphone. It takes the process id from the Core Audio session that `volume.rs` already finds, drains the stream every ~25 ms, mixes it to mono and hands it to the scope; nothing is recorded or kept beyond the scope's window. Capture runs on its own supervised thread and quietly retries when Spotify has no audio session yet. When nothing arrives (paused) it feeds silence, so the line goes flat instead of freezing.
- `waveform.rs`: the pure part, tested. `Scope` holds the last 1,200 mono samples (25 ms at 48 kHz) and reduces them to 200 points, each the sample with the biggest swing in its slice so peaks survive. Heights are scaled to a slowly decaying recent loudest sample, so a quiet intro and a loud chorus both use the box. It reports a flat line when no samples arrived for 300 ms.
- `ui/mod.rs` draws the line with a GPUI `canvas` and a stroked path over a faint baseline, and repaints about 30 times a second only while a track plays and the scope is live.

Gotcha found the hard way: the activation parameters travel in a `PROPVARIANT` whose blob points at a stack variable. Dropping a `PROPVARIANT` calls `PropVariantClear`, which frees that blob and corrupts the heap, so it is wrapped in `ManuallyDrop`.

A test that needs Spotify playing runs with `spotify-tests.exe --ignored captures_sound`. In previews (`PLAYER_UI_PREVIEW`), a synthetic signal feeds the scope.

## The backend link

`src/remote/` connects the player to the Première Écoute backend (contract: the backend repository's `docs/guides/desktop-player.md`, decisions: ADR 0001). The server is `PLAYER_HUB_URL` if set, else the address saved with the "Connect to server" button in the footer, else the build default (`config::DEFAULT_SERVER`): `https://premiere-ecoute.fr` for a normal build, `http://localhost:4000` for a build with `--features dev-server`.

```
UI thread ── Request(Local) ───────────────▶ player worker (player::run)
remote worker ── Request(Remote, deadline) ─▶       │  Reply (Done, Failed, Expired)
   │  step(): token, dial, Session::run, decide what next         ▼
   │  reads the shared Snapshot every second, writes RemoteStatus ack to the backend
   └── wss/ws ──▶ backend (topic desktop:me)
```

| File | Role |
|---|---|
| `protocol.rs` | Pure: Phoenix V2 frames, the snapshot payload, command validation (strict allow-list, `spotify:track:` plus 22 characters, volume range), `Inbound` events |
| `session.rs` | One connection from join to end, against `Transport`, `Clock` and `Executor` traits: first snapshot right after the join, snapshots at the server's interval, heartbeat with liveness timeout, dedup of command ids, acks |
| `retry.rs` | Full-jitter backoff (`random(0, min(60 s, 1 s * 2^n))`, never under 250 ms) and the memory of the last 256 command ids |
| `oauth.rs`, `auth.rs` | PKCE, the loopback listener, token calls; `Auth` refreshes before expiry and keeps the rotated refresh token in memory before writing it |
| `credentials.rs` | Windows Credential Manager (one entry per server address); the access token is never stored |
| `transport.rs`, `http.rs` | `tungstenite` WebSocket with timeouts and `X-Access-Token`; blocking HTTP with no redirects |
| `mod.rs` | `Worker::step` decides what to do after each way a session can end; `drive` waits with a countdown and reacts to Sign in and Sign out; `start` runs it under `supervise` |

What the worker does when a session ends:

| Ends with | Next |
|---|---|
| Network error, timeout, channel closed | Retry after the backoff delay; a session that lasted 30 s resets the backoff |
| `disconnect: replaced` | Retry after at least 60 s |
| `disconnect: revoked` or join `forbidden` | Forget the credential, wait for the user to sign in |
| Join refused (`unsupported_protocol`) | Show the failure, retry in 5 minutes |
| Socket refuses the access token | Refresh once and retry; a second refusal means sign in again |
| The user signs out | End the session, revoke, forget |

Commands from the backend go to the same player worker as the buttons, as a `Request` with a deadline and a reply channel. The reply becomes the ack, so a command never runs twice (dedup), never runs late (the deadline, from the relative `ttl_ms`) and `ok` really means Spotify accepted it.

`identity.rs` supplies the snapshot's `uri`: Windows does not expose Spotify's track URI, and the backend detects track changes by comparing it. See the amendment in ADR 0001.

Try it against a local backend: start the player, click "Connect to server" in the footer, keep the address `http://localhost:4000` and press Connect (or Enter). The address is saved in `%APPDATA%\premiere-ecoute-player\server.txt`, so the next start reconnects by itself. The footer then shows "Sign in": click it, approve in the browser (you need to be logged in to the backend with Twitch), and the server band shows `Server linked`. `PLAYER_HUB_URL` overrides the saved address, for scripts and development.

## Error handling

All backend methods return `Result<_, String>`. The `windows` crate's `Error` is converted at the edge with `map_err(err)` and propagated with `?`, so each function reads top to bottom with no nested matching. A `String` keeps the core free of Windows types, which is why it can be compiled and tested on any target.

There are two kinds of failure, kept apart in `Snapshot`:

- **`error`**: the backend itself failed (`snapshot()` returned `Err`). `can_control()` is false, so the controls are disabled and the title area says Spotify can't be read. It clears on the next successful poll.
- **`notice`**: a *command* failed (for example Next with no session). The player is still usable, so the controls stay enabled and the UI shows "Last action failed: …". `run` remembers the message with a timestamp and re-applies it to every snapshot for `NOTICE_HOLD` (4 s). Without that, the poll that follows each command would overwrite the message within a few milliseconds.

A backend never panics the worker thread; lock `unwrap()`s only panic if another thread panicked while holding the mutex.

Absence is not an error: no Spotify session gives `Snapshot::not_running()` (the window shows "Nothing playing" and how to fix it), and no audio session gives `volume: None`.

## Testing

Test-first. Tests live in dedicated files next to the code they test (`foo.rs` declares `#[cfg(test)] mod tests;`, the tests are in `foo/tests.rs`), and `use super::*;` keeps private items reachable. The suite has about 136 unit tests plus one that needs Spotify playing (`--ignored`).

What is covered:

- **Pure logic:** the snapshot model, request and reply handling, the worker loop with a `Fake` backend (it records calls, with no fixed sleeps: tests drop the sender to end the loop and `join()` the thread), restart policy, track identity, palette contrast for every hue, the ruler, the live scope.
- **Protocol and connection:** frame codec and command validation against the backend guide's examples, the whole session state machine against a fake transport and clock (join, heartbeat timeout, dedup, expiry, acks, cancel), backoff, the worker's decision after each way a session can end, the token manager (rotation, failing store, dead credential), PKCE with the RFC 7636 vector.
- **Real I/O on localhost:** the loopback sign-in listener, the HTTP client against a one-request server, the WebSocket transport and a full session (join, snapshot, command, ack, revoke) against a local WebSocket server, and the Windows Credential Manager round trip.
- **Not automated:** the Windows media and audio paths (`smtc.rs`, `volume.rs`, the capture beyond the ignored test) and the window itself. They need a real Spotify and a desktop, and are checked by running the app and with `tools/shot.sh` screenshots.

Because the code is compiled for Windows, tests run as a Windows executable (see below).

## Build pipeline

The Windows host has Rust (MSVC target) and Visual Studio but not the C++ workload or the Windows SDK, and GPUI needs both to build natively. So the project is cross-compiled from WSL.

```
cargo xwin build --target x86_64-pc-windows-msvc --release
cargo xwin test  --target x86_64-pc-windows-msvc --release --no-run
```

- **`cargo-xwin`** downloads the Windows SDK and C runtime headers/libs on first use and links with `lld-link`.
- **apt packages** `clang lld llvm` provide `llvm-rc`, which GPUI's build script needs to compile its Windows resource file, and the C tooling for native dependencies.
- **Running**: WSL can execute Windows binaries directly. Copy the `.exe` to `/mnt/c/Users/lanfe/` and run it. A running exe is locked by Windows, so use a new filename per build.
- **Tests** are built with `--no-run`, then the produced test exe is copied to Windows and run with an optional filter, for example `spotify-tests.exe player::tests::parse_track`.
- **`--release` is required**: GPUI's debug builds compile shaders at runtime from source files on the build machine, which do not exist on the target.

### The shader workaround

GPUI's `gpui-pre-windows` crate compiles its 9 HLSL shaders (vertex and fragment variants, 18 blobs) in `build.rs` by running `fxc.exe`. The script is gated on `#[cfg(target_os = "windows")]`, which in a build script means the **host**. Cross-compiling from Linux therefore skips shader compilation and the crate fails to build because the generated `shaders_bytes.rs` is missing.

The fix has three parts:

1. **`tools/hlslc`**: a small Rust program (itself cross-compiled) that calls `D3DCompile` from the `d3dcompiler_47.dll` already present on every Windows machine. It stands in for `fxc.exe`, which is not available here.
2. **`tools/gen-shaders.sh`**: inlines the one `#include` in the HLSL sources, runs `hlslc` through WSL interop for every entry point, and writes `vendor/gpui-pre-windows/shaders_bytes.rs`.
3. **`vendor/gpui-pre-windows`**: a copy of the crate whose `build.rs` just copies that pre-generated file into `OUT_DIR`. `Cargo.toml` points at it with `[patch.crates-io]`.

Regenerate the shaders with `tools/gen-shaders.sh` after upgrading GPUI, and re-vendor the matching crate version.

Building natively on Windows is not set up: it would need the Visual Studio C++ workload and the Windows SDK, which are not installed.

## Known limitations

- **No seek.** The ruler is display-only. SMTC supports `TryChangePlaybackPositionAsync`.
- **Tracks only.** `parse_track_uri` and the backend's `play_uri` accept tracks, not albums or playlists.
- **Undocumented behaviour.** `?autoplay=true` is not a documented Spotify interface.
- **Single Spotify session.** The first matching SMTC session wins.
- **The track `uri` sent to the backend is a stand-in** for tracks the player did not start (see `identity.rs`).
- **The waveform is the last 25 ms**, not the track, and needs Windows 10 2004 or newer.
- **Unverified tuning.** `POLL` (750 ms), `VOLUME_HOLD` (1.5 s) and the waveform's gain curve were chosen by reasoning.

The full list of bugs, gaps and tidy-ups, with priorities, is in [refactoring.md](refactoring.md).

## Extending

- **New action** (for example seek): add a `Command` variant and a `Backend` method; add the Windows call in `smtc.rs`; add a branch in `run`; add a control in `render()`. Write the `Fake`-backed test in `player/tests.rs` first.
- **Another platform**: implement `Backend` for it (MPRIS over D-Bus on Linux is the obvious equivalent) and add it in `main.rs`. The core and UI need no changes; the capture, the media session and the credential store are Windows-specific today (see refactoring.md, B6).
- **More state in the UI**: add a field to `Snapshot`, fill it in `smtc.rs`, and add a presentation helper next to `state_label()` with a test.
