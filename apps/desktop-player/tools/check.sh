#!/usr/bin/env bash
# The quality gates of docs/quality.md in one go, the same as CI plus the tests run on Windows through tools/win-run.sh.
# usage: tools/check.sh
set -euo pipefail
cd "$(dirname "$0")/.."
target=x86_64-pc-windows-msvc
export CARGO_TARGET_X86_64_PC_WINDOWS_MSVC_RUNNER=$PWD/tools/win-run.sh

step() { printf '\n==> %s\n' "$1"; shift; "$@"; }

step "format" cargo fmt --check
step "lint" cargo xwin clippy --target $target --release --all-targets --no-deps -- -D warnings
step "tests" cargo xwin test --target $target --release
step "unused dependencies" cargo machete
step "advisories, licenses, bans, sources" cargo deny check
printf '\nAll checks passed.\n'
