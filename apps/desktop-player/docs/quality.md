# Quality gates

`.github/workflows/pr-desktop-player.yml` runs format, lint, tests, machete and deny on every pull request, natively on a Windows runner (no `cargo-xwin`, and the tests actually run). Run the gates below by hand from WSL before pushing. `cargo audit` is not in CI: it scans the whole `Cargo.lock`, including Linux-only crates the exe never links.

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

## Rules

- Format with one `cargo fmt` commit, never mixed with other changes.
- Never silence a lint with `#[allow]` without a comment saying why. Prefer fixing the cause (for `too_many_arguments`, take a struct).
- Every `unsafe` block gets a `// SAFETY:` comment. `Cargo.toml` enables `clippy::undocumented_unsafe_blocks`, so the lint gate enforces it.
- A new license needs a decision: add it to `[licenses] allow` in `deny.toml` only after checking it.
- Run `cargo audit` and `cargo deny check advisories` regularly: the advisory database changes without any change in this repository.

## Known limits

- **Coverage is not measured**: `cargo llvm-cov` builds for the Linux host and the code only compiles for Windows. It would need an instrumented Windows exe and `llvm-profdata` on the `.profraw` files.
- `smtc.rs`, `volume.rs`, the capture and the window have no automated tests (refactoring.md D).
