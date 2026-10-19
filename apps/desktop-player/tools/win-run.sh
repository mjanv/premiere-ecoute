#!/usr/bin/env bash
# Cargo runner: copy a cross-compiled exe to Windows under a fixed name, stop the previous run, execute it.
# Lets `cargo xwin run` / `cargo xwin test` work from WSL without a new filename per build.
# usage (as a runner): export CARGO_TARGET_X86_64_PC_WINDOWS_MSVC_RUNNER=$PWD/tools/win-run.sh
#   WIN_DIR   Windows directory to copy into, as a WSL path (default: the Windows user's profile)
#   PLAYER_HUB_URL is forwarded to the exe, e.g. PLAYER_HUB_URL=http://localhost:4000 for a local backend
set -euo pipefail
exe=$1; shift

source "$(dirname "$0")/lib.sh"
win_dir=$(win_dir)
case $(basename "$exe") in
  premiere-ecoute-player*) name=pep-dev ;;
  *) name=pep-tests ;;
esac

taskkill.exe /F /IM "$name.exe" >/dev/null 2>&1 || true
# Windows releases the old exe a moment after taskkill returns: retry the copy for a few seconds.
for _ in $(seq 20); do
  cp "$exe" "$win_dir/$name.exe" 2>/dev/null && break
  sleep 0.5
done
cp "$exe" "$win_dir/$name.exe"

if [ -n "${PLAYER_HUB_URL:-}" ]; then export WSLENV="${WSLENV:+$WSLENV:}PLAYER_HUB_URL"; fi
exec "$win_dir/$name.exe" "$@"
