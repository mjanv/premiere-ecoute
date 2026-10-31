# AGENTS.md

This file provides guidance to coding agents when working with code in this repository.

Windows desktop app (GPUI via `gpui-kit`) that reads and controls the **local** Spotify desktop app. No Spotify Web API. Development happens in WSL2; the target is native Windows (`x86_64-pc-windows-msvc`).

## Build and test

The code only runs on Windows, and the Windows host has no MSVC linker / Windows SDK, so everything is **cross-compiled from WSL** with `cargo-xwin` (needs `clang lld llvm` from apt):

```
cargo xwin build --target x86_64-pc-windows-msvc --release
cargo xwin test  --target x86_64-pc-windows-msvc --release --no-run   # then run the test exe on Windows
```

Plain `cargo build` / `cargo test` on Linux does not work. There is no native Windows build path (no C++ workload / SDK installed).

Dev build against a local backend: add `--features dev-server` to the build/test commands. Plain builds and `tools/package.sh` target production (`https://premiere-ecoute.fr`).

Package for users with `tools/package.sh` (installer + portable zip in `dist/`, see `docs/distribution.md`).

Fastest dev loop: `just player` from the monorepo root runs the app on Windows against this checkout's server (port from `just info`) and rebuilds and restarts it on every change under `src/`, `assets/`, `build.rs` or `Cargo.toml` (needs `watchexec`: `cargo install --locked watchexec-cli`). Underneath, set `CARGO_TARGET_X86_64_PC_WINDOWS_MSVC_RUNNER=$PWD/tools/win-run.sh`, then `cargo xwin run --target x86_64-pc-windows-msvc --release` (or `cargo xwin test ... -- <filter>`) copies the exe to Windows under a fixed name, stops the previous run and executes it. Set `WIN_DIR` to change the Windows directory (default: the Windows user's profile) and `PLAYER_HUB_URL=http://localhost:4000` to use a local backend with a plain build, no `dev-server` feature needed.

`just player-test <filter>` runs the tests the same way (`just player-test remote::session`), `just player-check` runs every quality gate of `docs/quality.md` (`tools/check.sh`), and `tools/live.sh` runs the live checks against the real Spotify desktop app (see `docs/quality.md`), `just player-smoke` starts the release exe without Spotify and checks that its window opens (`tools/smoke.sh`). Scripts that reach Windows share `tools/lib.sh`, which finds your Windows profile (`WIN_DIR` overrides it) and temp directory: nothing is hardcoded to a user name.

Debug builds of GPUI compile shaders at runtime from source paths, so use `--release`.

## Tests

Tests live in dedicated files, never inline. A module `foo.rs` ends with `#[cfg(test)] mod tests;` and its tests are in `foo/tests.rs` (for `foo/mod.rs`: `foo/tests.rs`). The test file starts with `use super::*;`, so it still reaches private items. Run one with a filter on the test exe, for example `spotify-tests.exe remote::session`.

## Architecture

- `src/player.rs`: platform-independent core. `Snapshot` (what the UI renders; `error` = player unusable, `notice` = last command failed, kept for a few seconds), `Backend` trait, `Command` enum, and `run()`, a loop that polls the backend into an `Arc<Mutex<Snapshot>>` and applies `Command`s received on an mpsc channel. Commands travel as `Request` (with an optional reply channel and deadline). Pure helpers live here too (`parse_track_uri`, `autoplay_uri`, `current_position`, `format_time`). Add new features test-first here, then wire into the backend and UI.
- `src/smtc.rs` (`cfg(windows)`): `Backend` implementation. Metadata, play/pause, next/previous, and position come from Windows SMTC (`GlobalSystemMediaTransportControlsSessionManager`), filtering the session whose AppUserModelId contains "spotify".
- `src/capture.rs` (`cfg(windows)`) and `src/waveform.rs`: the live waveform. `capture.rs` captures only Spotify's audio (per-process loopback) and keeps nothing beyond a ~25 ms window; `waveform.rs` is the pure, tested `Scope` behind the oscilloscope line. Never drop the `PROPVARIANT` that carries the activation parameters (see `docs/architecture.md`).
- `src/volume.rs` (`cfg(windows)`): Spotify's per-app volume through Core Audio sessions (`IAudioSessionManager2` → `ISimpleAudioVolume`). SMTC has no volume. The session only exists once Spotify has played audio, hence `Snapshot::volume: Option<f32>`.
- `src/remote/`: the link to the backend (server = `PLAYER_HUB_URL`, else the address saved in `%APPDATA%\premiere-ecoute-player\server.txt` by the footer's "Connect to server" button, else the build default `remote::config::DEFAULT_SERVER`: `https://premiere-ecoute.fr`, or `http://localhost:4000` when built with `--features dev-server`). Pure and tested: `protocol.rs`, `session.rs` (state machine over `Transport`/`Clock`/`Executor`), `retry.rs`, `oauth.rs`, `auth.rs`. Real I/O: `transport.rs`, `http.rs`, `credentials.rs`. `mod.rs` holds the supervised worker. Contract: `docs/guides/desktop-player.md` at the monorepo root; see `docs/architecture.md` and ADR 0001 amendment 1. `src/identity.rs` makes the snapshot's `uri`; `src/log.rs` is the log file (`%LOCALAPPDATA%\premiere-ecoute-player\player.log`; silent until `log::init()`; never log tokens); `src/start.rs` checks that a commanded track plays from its beginning and walks back to track 1 when Spotify resumed the loaded track instead (it fails the command when it cannot); `src/ending.rs` is how a commanded track's end is reported (playing at its very end, then paused; a leaked next track is paused again and never shown); `src/instance.rs` (`cfg(windows)`) keeps one player per PC with a named mutex; `src/light.rs` is the pure status light (green, amber, red, grey) from the snapshot and the backend link, shown by `src/taskbar.rs` (overlay badge on the taskbar button) and `src/tray.rs` (notification-area icon on its own thread; minimizing hides the window to it, a left click restores it, the right-click menu has Open and Quit); `src/supervise.rs` restarts crashed workers.
- `src/ui/` and `src/main.rs`: GPUI view (`ui/mod.rs`: verdict, checklist, now playing, footer actions), pure design logic with tests (`ui/palette.rs`, `ui/ruler.rs`, `artwork.rs`), `remote_status.rs` for the backend link, and `status.rs` (pure: the verdict and the checklist rows the window draws, `Session` being what the server reports through the `session` event, kept in `RemoteStatus.session`; a new signal is a new row there, test-first). `main.rs` only wires state, fonts, assets and the window. A backend thread runs `player::run`; the UI polls the shared snapshot on a timer and sends `Command`s. The volume slider ignores polled values for `VOLUME_HOLD` after user input so the thumb does not jump back.

## Rules of thumb

- Test-first for logic; the pure parts (`player`, `remote/protocol`, `remote/session`, `waveform`, `ui/palette`, ...) are where tests pay off.
- Never drop the `PROPVARIANT` that carries the audio activation parameters, and never build with `panic = "abort"` (the supervisors catch panics).
- A Windows API call you cannot test (`smtc.rs`, `volume.rs`, `capture.rs`) still gets its decisions pulled out into a small pure function with a test next to it (`is_spotify_app`, `since_update`, `silent_pass_len`).
- Update `docs/architecture.md`, `docs/ui.md` and this file in the same change as the code.

## Non-obvious details

- **Starting a track**: `spotify:track:<id>` alone only opens the album page. The backend appends `?autoplay=true` (verified against the desktop client; `:play`, `?play=true`, and `--uri=` did not work) and launches it via `rundll32 url.dll,FileProtocolHandler`. The desktop app then continues with the album, which no URI variant avoids, so the player pauses the commanded track at its end (`player::StopAtEnd`, `Backend::pause`, `ending.rs`) and hides that from the backend. It also checks that the track really starts from its beginning and repairs the one case where Spotify resumes instead (`start.rs`); see `docs/architecture.md`. Try it against a real Spotify, with a build using `--features dev-tools` (`just player` does), with `PLAYER_DEV_PLAY=spotify:track:<id>` (with `PLAYER_DEV_TRACK=<n>` for its position in its album, as the backend sends it) and `PLAYER_DEV_SESSION=1`. While a session runs (backend `session` event), whatever plays is guarded, not only commanded tracks.
- **SMTC position** is only the value at the last update; `current_position` adds elapsed time while playing.
- **Cross-compiling GPUI shaders**: upstream `gpui-pre-windows`'s `build.rs` only runs `fxc` when the *host* is Windows. `vendor/gpui-pre-windows` is a copy with a patched `build.rs` that copies a pre-generated `shaders_bytes.rs`, wired via `[patch.crates-io]` in `Cargo.toml`. Regenerate it with `tools/gen-shaders.sh` after a GPUI version bump; it uses `tools/hlslc` (a tiny `D3DCompile` wrapper, built with `cargo xwin build` inside `tools/hlslc`) run through WSL interop, because no `fxc.exe` is available.
- `windows` crate async calls are blocked on with the inherent `.join()`, not `.get()`.

See `docs/architecture.md` for the full walkthrough and `docs/ui.md` for the UI design (the verdict and checklist, status colours, palette from the cover, type, ruler). Look at the UI with `tools/shot.sh` and `PLAYER_UI_PREVIEW`; both are described there.

Decisions: `docs/adr/` (0001: remote control via Phoenix Channels, accepted and implemented). What to tidy next, with priorities: `docs/refactoring.md`. The backend contract is `docs/guides/desktop-player.md` at the monorepo root.
