#!/usr/bin/env bash
# Live checks of the player against the real Spotify desktop app on Windows (see tools/live/live.ps1).
# They take over what plays: run them when nothing important is on, with Spotify open and signed in.
# usage: tools/live.sh [end|first-track|other-album|shuffle|restart|all]   (default: all)
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/lib.sh
scenario=${1:-all}

# The dev tools are what lets the player be commanded without a backend; never in a build for users.
cargo xwin build --target x86_64-pc-windows-msvc --release --features dev-tools
exe_name=pep-live.exe
cp target/x86_64-pc-windows-msvc/release/premiere-ecoute-player.exe "$(win_dir)/$exe_name"
trap 'rm -f "$(win_dir)/$exe_name"' EXIT

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w tools/live/live.ps1)" \
  -Exe "$(wslpath -w "$(win_dir)/$exe_name")" -Scenario "$scenario" | tr -d '\r'
