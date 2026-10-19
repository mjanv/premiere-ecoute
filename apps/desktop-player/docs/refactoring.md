# Refactoring and follow-ups

State at the end of the first proof of concept (2026-10-12): the player works end to end (local control, cover-tinted window, live waveform, link to the Première Écoute backend with sign-in and sign-out). 136 unit tests plus one live test. This file lists what to tidy, in priority order. Each item says why and gives a first step. It is a menu, not a plan to do everything.

Already decided: tests live in dedicated files (`foo/tests.rs`, see `AGENTS.md`).

## A. Bugs and gaps to close first

| # | Item | Why | First step |
|---|---|---|---|
| A1 | **Second instance steals the connection** | The backend allows one player per user. Starting the exe twice makes the older one show "replaced" and wait 60 s offline | Single-instance guard (named mutex via `CreateMutexW`); the second launch exits or focuses the first |
| A2 | **No logging at all** | The release exe has no console. Panics, failed captures and failed token refreshes leave no trace; `main.rs` passes `\|_, _\| {}` as the crash hook of `player-worker` and `audio-capture`, and `capture::run` discards errors with `let _ =` | Log file in `%LOCALAPPDATA%\premiere-ecoute-player\`, a panic hook, log state transitions, backoff delays, ack outcomes (never tokens). ADR rule R10 |
| A3 | **Sign-in cannot be cancelled** | `Auth::sign_in` blocks the worker up to 5 minutes (`SIGN_IN_TIMEOUT`); the footer says "Waiting for the browser" with nothing to click | Cancel button, and a cancel flag checked in `oauth::wait_for_callback`'s loop |
| A4 | **Server address cannot be changed from the window** | Once saved, only deleting `%APPDATA%\premiere-ecoute-player\server.txt` changes it | "Change server" action that clears the saved address and returns to "Local only" |
| A5 | **Track `uri` is an assumption** | Windows does not expose the Spotify track URI; `identity.rs` sends the URI of the last `play_uri` or a synthetic `spotify:local:…` string. The backend only compares it for change | Confirm with the backend; look for a real source of the URI |
| A6 | **Two backend checks never run** | Killing the player should return the backend to Web API polling; two instances should give "replaced" | Run step 8 of the backend guide's end-to-end test |
| A7 | **Backend: first login loses the authorize request** (other repo) | `auth_controller.ex:75` sets the return page to `/` after the Twitch callback, so a first login needs a second click on Sign in | Do not overwrite `user_return_to` when it points at `/oauth/authorize` |
| A8 | **Volume errors are swallowed** | `volume::get().unwrap_or(None)` shows "Volume unavailable" for any Core Audio failure | Carry the error (or log it, once A2 exists) |

## B. Structure

| # | Item | Detail |
|---|---|---|
| B1 | **`ui/mod.rs` is 682 lines; `render` is about 400** | Split into functions or small components: cover, heading, timeline, waveform, transport, volume, footer. The pill buttons (Sign in, Connect to server, Connect, Sign out) repeat the same styling: one helper |
| B2 | **`player.rs` mixes four jobs** | Snapshot model, command/request/reply types, URI helpers, worker loop. Split into `player/{snapshot,request,worker}.rs` |
| B3 | **`remote/mod.rs` (412 lines) holds settings, dialer, browser opener, worker, handle** | Move settings and the worker to their own files |
| B4 | **Errors are `String` everywhere, and some code decides by comparing text** | `End::Refused(String)` is compared to `"forbidden"`; join reasons and disconnect reasons are strings. Small enums for backend, auth and join errors |
| B5 | **Clippy: 10 warnings** | 4 collapsible `if`, 2 `manual_is_multiple_of`, 2 `chunks_exact` with a constant size, 2 `too_many_arguments` (`Worker::new` with 8, `ui::control` with 9: take a small struct) |
| B6 | **Dead non-Windows code** | `cfg(not(windows))` stubs in `main.rs` and `remote/mod.rs` (`NoBrowser`, `MemoryStore`). The app and its tests only run on Windows: delete them, or support Linux for real |
| B7 | **Duplicated test fakes** | A fake clock (`remote/session/tests.rs`, `remote/tests.rs`), a fake HTTP client and a shared credential store (`remote/auth/tests.rs`, `remote/tests.rs`), scripted transports. One `#[cfg(test)]` support module |
| B8 | **Crash hooks do nothing** | `supervise` calls `on_crash`; for the player worker and the capture it is a no-op. Show or log the crash |
| B9 | **Polling cost** | SMTC session manager requested every 750 ms; the capture thread enumerates Core Audio sessions every second while Spotify has none. Cache what can be cached |
| B10 | **First SMTC session wins** | `spotify_session()` returns the first session whose id contains "spotify" |
| B11 | **Optional: library crate** | Integration tests in a top-level `tests/` folder need a library target (a binary's private items are not reachable). Only worth it if that layout is wanted; today's `foo/tests.rs` reaches private items |

## C. Delivery

| # | Item | Detail |
|---|---|---|
| C1 | **Not installable yet** | No icon, version info or manifest (including DPI awareness), no installer or zip, no code signing, no autostart, no auto-update. "Installable on Windows without WSL" was the goal |
| C2 | **Release profile is untuned** | Add `lto`, `strip`, `codegen-units`. **Never `panic = "abort"`**: the supervisors rely on `catch_unwind` |
| C3 | **Manual build and test steps** | Copying exes by hand, `/mnt/c/Users/lanfe` hard-coded in `AGENTS.md` and `tools/shot.sh`. One build and one test script, a configurable Windows directory |
| C4 | **Vendored GPUI crate and pre-generated shaders** | Re-run `tools/gen-shaders.sh` and re-vendor on every GPUI upgrade (procedure in `docs/architecture.md`). Consider an upstream fix to the host-gated `build.rs` |
| C5 | **CI is minimal** | `pr-desktop-player.yml` and `release-desktop-player.yml` cover build, tests and release. No scheduled advisory check, no coverage |

## D. Tests

- Not automated: `smtc.rs`, `volume.rs`, the capture beyond the `--ignored` test that needs Spotify playing, and the window. Candidates: a smoke test that starts the exe with `PLAYER_UI_PREVIEW` and checks the window appears (`tools/shot.sh` already does the capture), or screenshot comparison.
- End-to-end against the real backend is manual (backend guide, "End-to-end test with your account"). A script would make it repeatable.

## E. Docs

- `docs/adr/0001-…`: sections 4, 5 and parts of 13 are superseded by the backend guide and Amendment 1 but still sit in the body. Consider moving them to an appendix or trimming.
- `docs/architecture.md`, `docs/ui.md` and `AGENTS.md` drift whenever code changes; update them in the same change.

## F. Decisions waiting for you

- Library crate or not (B11).
- Linux support or Windows only (B6).
- Send snapshots only on change, plus a light heartbeat, instead of every second (ADR section 11).
- Multi-PC per user: the backend guide says exactly one player per user; revisit only if that changes.
