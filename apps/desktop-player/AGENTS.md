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

Run a cross-compiled exe through WSL interop: copy it to `/mnt/c/Users/lanfe/` and execute it. A running exe is locked by Windows, so use a new filename per build (`premiere-ecoute-player-vN.exe`). Single test: run the test exe with a filter, e.g. `/mnt/c/Users/lanfe/spotify-tests.exe player::tests::parse_track`.

Debug builds of GPUI compile shaders at runtime from source paths, so use `--release`.

## Tests

Tests live in dedicated files, never inline. A module `foo.rs` ends with `#[cfg(test)] mod tests;` and its tests are in `foo/tests.rs` (for `foo/mod.rs`: `foo/tests.rs`). The test file starts with `use super::*;`, so it still reaches private items. Run one with a filter on the test exe, for example `spotify-tests.exe remote::session`.

## Architecture

- `src/player.rs`: platform-independent core. `Snapshot` (what the UI renders; `error` = player unusable, `notice` = last command failed, kept for a few seconds), `Backend` trait, `Command` enum, and `run()`, a loop that polls the backend into an `Arc<Mutex<Snapshot>>` and applies `Command`s received on an mpsc channel. Commands travel as `Request` (with an optional reply channel and deadline). Pure helpers live here too (`parse_track_uri`, `autoplay_uri`, `current_position`, `format_time`). Add new features test-first here, then wire into the backend and UI.
- `src/smtc.rs` (`cfg(windows)`): `Backend` implementation. Metadata, play/pause, next/previous, and position come from Windows SMTC (`GlobalSystemMediaTransportControlsSessionManager`), filtering the session whose AppUserModelId contains "spotify".
- `src/capture.rs` (`cfg(windows)`) and `src/waveform.rs`: the live waveform. `capture.rs` captures only Spotify's audio (per-process loopback) and keeps nothing beyond a ~25 ms window; `waveform.rs` is the pure, tested `Scope` behind the oscilloscope line. Never drop the `PROPVARIANT` that carries the activation parameters (see `docs/architecture.md`).
- `src/volume.rs` (`cfg(windows)`): Spotify's per-app volume through Core Audio sessions (`IAudioSessionManager2` → `ISimpleAudioVolume`). SMTC has no volume. The session only exists once Spotify has played audio, hence `Snapshot::volume: Option<f32>`.
- `src/remote/`: the link to the backend (server = `PLAYER_HUB_URL`, else the address saved in `%APPDATA%\premiere-ecoute-player\server.txt` by the footer's "Connect to server" button, else the build default `remote::config::DEFAULT_SERVER`: `https://premiere-ecoute.fr`, or `http://localhost:4000` when built with `--features dev-server`). Pure and tested: `protocol.rs`, `session.rs` (state machine over `Transport`/`Clock`/`Executor`), `retry.rs`, `oauth.rs`, `auth.rs`. Real I/O: `transport.rs`, `http.rs`, `credentials.rs`. `mod.rs` holds the supervised worker. Contract: `docs/guides/desktop-player.md` at the monorepo root; see `docs/architecture.md` and ADR 0001 amendment 1. `src/identity.rs` makes the snapshot's `uri`; `src/supervise.rs` restarts crashed workers.
- `src/ui/` and `src/main.rs`: GPUI view (`ui/mod.rs`), pure design logic with tests (`ui/palette.rs`, `ui/ruler.rs`, `artwork.rs`), `remote_status.rs` for the backend link shown in the footer. `main.rs` only wires state, fonts, assets and the window. A backend thread runs `player::run`; the UI polls the shared snapshot on a timer and sends `Command`s. The volume slider ignores polled values for `VOLUME_HOLD` after user input so the thumb does not jump back.

## Rules of thumb

- Test-first for logic; the pure parts (`player`, `remote/protocol`, `remote/session`, `waveform`, `ui/palette`, ...) are where tests pay off.
- Never drop the `PROPVARIANT` that carries the audio activation parameters, and never build with `panic = "abort"` (the supervisors catch panics).
- Update `docs/architecture.md`, `docs/ui.md` and this file in the same change as the code.

## Non-obvious details

- **Starting a track**: `spotify:track:<id>` alone only opens the album page. The backend appends `?autoplay=true` (verified against the desktop client; `:play`, `?play=true`, and `--uri=` did not work) and launches it via `rundll32 url.dll,FileProtocolHandler`. The desktop app then continues with the album, which no URI variant avoids, so `player::StopAtEnd` pauses the track in its last second.
- **SMTC position** is only the value at the last update; `current_position` adds elapsed time while playing.
- **Cross-compiling GPUI shaders**: upstream `gpui-pre-windows`'s `build.rs` only runs `fxc` when the *host* is Windows. `vendor/gpui-pre-windows` is a copy with a patched `build.rs` that copies a pre-generated `shaders_bytes.rs`, wired via `[patch.crates-io]` in `Cargo.toml`. Regenerate it with `tools/gen-shaders.sh` after a GPUI version bump; it uses `tools/hlslc` (a tiny `D3DCompile` wrapper, built with `cargo xwin build` inside `tools/hlslc`) run through WSL interop, because no `fxc.exe` is available.
- `windows` crate async calls are blocked on with the inherent `.join()`, not `.get()`.

See `docs/architecture.md` for the full walkthrough and `docs/ui.md` for the UI design (palette from the cover, type, ruler, footer). Look at the UI with `tools/shot.sh` and `PLAYER_UI_PREVIEW`; both are described there.

Decisions: `docs/adr/` (0001: remote control via Phoenix Channels, accepted and implemented). What to tidy next, with priorities: `docs/refactoring.md`. The backend contract is `docs/guides/desktop-player.md` at the monorepo root.
