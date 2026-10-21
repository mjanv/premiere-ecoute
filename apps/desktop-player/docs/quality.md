# Quality gates

`.github/workflows/pr-desktop-player.yml` runs format, lint, tests, machete and deny on every pull request, natively on a Windows runner (no `cargo-xwin`, and the tests actually run). `tools/check.sh` (`just player-check` from the monorepo root) runs the same gates from WSL, with the tests executed on Windows: run it before pushing. `cargo audit` is not in CI: it scans the whole `Cargo.lock`, including Linux-only crates the exe never links.

## Tools

```
cargo install --locked cargo-deny cargo-audit cargo-machete
```

`rustfmt` and `clippy` come with the toolchain.

## Gates

| Gate | Command | Passes when |
|---|---|---|
| Format | `cargo fmt --check` | No diff |
| Lint | `cargo xwin clippy --target x86_64-pc-windows-msvc --release --all-targets --no-deps -- -D warnings` | No warning |
| Tests | `cargo xwin test --target x86_64-pc-windows-msvc --release --no-run`, then run the exe on Windows (see `AGENTS.md`) | All tests pass |
| Unused dependencies | `cargo machete` | Nothing reported, or the crate is listed under `[package.metadata.cargo-machete] ignored` with a reason |
| Vulnerabilities | `cargo audit` | No vulnerability. "Unmaintained" warnings are reviewed, not blocking |
| Advisories, licenses, bans, sources | `cargo deny check` (`deny.toml` sets the Windows target) | Passes. Every ignored advisory in `deny.toml` has a reason; remove an entry once its crate is gone |

## Live checks

The unit tests drive a simulated Spotify. `tools/live.sh` (`tools/live.sh end` for one scenario) drives the **real** Spotify desktop app through the media session, to check what the simulation only assumes. It needs Spotify open and signed in on the Windows PC, takes over what plays, and uses a build with `--features dev-tools` that never joins a server, so it can run next to a real player.

| Scenario | Checks |
|---|---|
| `end` | A commanded track is paused at its end and the next track never starts |
| `first-track` | The first track of an album that was just left is started, not resumed |
| `other-album` | Another album plays and the album was left on track 4: track 1 is what plays |
| `shuffle` | Shuffle and repeat are turned off before the track is asked for |
| `restart` | A song already playing when the player starts is guarded while a session runs |

Run it after a Spotify update, and when the start or end logic changes: it relies on undocumented client behaviour (see `docs/architecture.md`). The player's log (`%LOCALAPPDATA%\premiere-ecoute-player\player.log`) shows what it decided.

## Rules

- Format with one `cargo fmt` commit, never mixed with other changes.
- Never silence a lint with `#[allow]` without a comment saying why. Prefer fixing the cause (for `too_many_arguments`, take a struct).
- Every `unsafe` block gets a `// SAFETY:` comment. `Cargo.toml` enables `clippy::undocumented_unsafe_blocks`, so the lint gate enforces it.
- A new license needs a decision: add it to `[licenses] allow` in `deny.toml` only after checking it.
- Run `cargo audit` and `cargo deny check advisories` regularly: the advisory database changes without any change in this repository.

## Known limits

- **Coverage is not measured**: `cargo llvm-cov` builds for the Linux host and the code only compiles for Windows. It would need an instrumented Windows exe and `llvm-profdata` on the `.profraw` files.
- `smtc.rs`, `volume.rs` and `capture.rs` have tests for their decisions (which session is Spotify, the timeline arithmetic, the pass length), not for the Windows calls themselves: the capture needs Spotify playing (`--ignored`).
- The window has no unit tests. `tools/smoke.sh` (`just player-smoke`) starts the release exe with `PLAYER_UI_PREVIEW=idle` and fails if it exits or opens no window. It needs a desktop session, so it is not in CI.
