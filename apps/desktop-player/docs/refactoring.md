# Refactoring and follow-ups

State at the end of the first proof of concept (2026-10-12): the player works end to end (local control, cover-tinted window, live waveform, link to the Première Écoute backend with sign-in and sign-out). 136 unit tests plus one live test. This file lists what to tidy, in priority order. Each item says why and gives a first step. It is a menu, not a plan to do everything.

Already decided: tests live in dedicated files (`foo/tests.rs`, see `AGENTS.md`).

## A. Bugs and gaps to close first

| # | Item | Why | First step |
|---|---|---|---|
| A1 | ~~Second instance steals the connection~~ | Done: `src/instance.rs` takes the named mutex `Local\premiere-ecoute-player` at startup; a second launch exits at once. Previews (`PLAYER_UI_PREVIEW`) skip the check. Open idea: focus the first window instead of exiting silently |
| A2 | ~~No logging at all~~ | Done: `src/log.rs` writes `%LOCALAPPDATA%\premiere-ecoute-player\player.log` (rotated at 1 MB to `player.log.old`): start, panics, worker crashes, link changes, failed token refreshes and connections, session ends, command outcomes, audio capture failures, and one line per track with every SMTC field Spotify reported. Never tokens. Still open: volume errors (A8) are not logged |
| A3 | ~~Sign-in cannot be cancelled~~ | Done: the footer shows Cancel while waiting for the browser (`Handle::cancel_sign_in`, `oauth::wait_for_callback_until`) |
| A4 | ~~Server address cannot be changed from the window~~ | Done: "Change server" stops the link, forgets the saved address (`config::forget`) and opens the address field; the old server keeps its credential |
| A5 | ~~Track `uri` is an assumption~~ | Handled on the backend: `Discography.TrackMatch` finds the stored track from title, artist, length, album and track number, and the `Local` player mode swaps the made-up `spotify:local:…` uri for `spotify:track:<id>` (once per track). A song that is not stored keeps the made-up uri. Spotify reports `track_number` and `album_artist` but leaves `album_track_count` at 0 and genres empty (one track sampled, 2026-10-21) |
| A6 | Two backend checks never run | Partly done by use: stopping and restarting the player brought the backend back to polling and back (seen in a real session), and a second instance gets `replaced`. Token refresh after expiry was not exercised on its own |
| A7 | ~~Backend: first login loses the authorize request~~ | Done: `UserAuth.put_default_return_to/2` keeps a stored `/oauth/authorize` page after the Twitch callback |
| A8 | ~~Volume errors are swallowed~~ | Done: logged once when they appear or change (`new_volume_error`); the window still shows "Volume unavailable" |

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
| C3 | ~~Manual build and test steps~~ | Done: `tools/win-run.sh` (cargo runner), `tools/check.sh`, `tools/lib.sh` finds the Windows directory (`WIN_DIR` overrides it) |
| C4 | **Vendored GPUI crate and pre-generated shaders** | Re-run `tools/gen-shaders.sh` and re-vendor on every GPUI upgrade (procedure in `docs/architecture.md`). Consider an upstream fix to the host-gated `build.rs` |
| C5 | **CI is minimal** | `pr-desktop-player.yml` and `release-desktop-player.yml` cover build, tests and release. No scheduled advisory check, no coverage |

## D. Tests

- Not automated: the Windows calls in `smtc.rs`, `volume.rs` and `capture.rs` (their decisions are tested, the capture also has an `--ignored` test that needs Spotify playing), and what the window draws. `tools/smoke.sh` checks that the window opens; screenshot comparison is still open.
- End-to-end against the real backend is manual (backend guide, "End-to-end test with your account"). A script would make it repeatable.

## E. Docs

- `docs/adr/0001-…`: sections 4, 5 and parts of 13 are superseded by the backend guide and Amendment 1 but still sit in the body. Consider moving them to an appendix or trimming.
- `docs/architecture.md`, `docs/ui.md` and `AGENTS.md` drift whenever code changes; update them in the same change.

## F. Decisions waiting for you

- Library crate or not (B11).
- Linux support or Windows only (B6).
- Send snapshots only on change, plus a light heartbeat, instead of every second (ADR section 11).
- Multi-PC per user: the backend guide says exactly one player per user; revisit only if that changes.
