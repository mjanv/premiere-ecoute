#!/usr/bin/env bash
# Build the release exe and package it for people: dist/<name>-<version>-setup.exe (installer) and dist/<name>-<version>-portable.zip.
# usage: tools/package.sh          (needs cargo-xwin; makensis from `apt install nsis`, or NSISDIR + MAKENSIS set)
#
# Code signing is optional and off unless SIGN_PFX is set (needs `apt install osslsigncode`):
#   SIGN_PFX           path to the code signing certificate (.pfx / .p12)
#   SIGN_PFX_PASSWORD  its password
#   SIGN_TIMESTAMP_URL RFC 3161 timestamp server (default: http://timestamp.digicert.com)
# The exe is signed before it goes into the zip and the installer, then the installer is signed too.
set -euo pipefail
cd "$(dirname "$0")/.."
name=premiere-ecoute-player
version=$(sed -n 's/^version = "\(.*\)"/\1/p' Cargo.toml | head -1)
target=x86_64-pc-windows-msvc
exe=target/$target/release/$name.exe

sign() {
  [ -n "${SIGN_PFX:-}" ] || return 0
  command -v osslsigncode >/dev/null || { echo "SIGN_PFX is set but osslsigncode is missing (apt install osslsigncode)" >&2; exit 1; }
  osslsigncode sign -pkcs12 "$SIGN_PFX" -readpass <(printf %s "${SIGN_PFX_PASSWORD:-}") \
    -n "Premiere Ecoute Player" -h sha256 -ts "${SIGN_TIMESTAMP_URL:-http://timestamp.digicert.com}" \
    -in "$1" -out "$1.signed" >/dev/null
  mv "$1.signed" "$1"
  echo "signed $(basename "$1")"
}

[ -n "${SIGN_PFX:-}" ] || echo "SIGN_PFX not set: the exe and the installer are unsigned (SmartScreen will warn)" >&2

cargo xwin build --target $target --release

rm -rf dist && mkdir -p dist/stage
cp "$exe" "dist/stage/$name.exe"
sign "dist/stage/$name.exe"
(cd dist/stage && zip -q "../$name-$version-portable.zip" "$name.exe")

makensis=${MAKENSIS:-$(command -v makensis || true)}
if [ -n "$makensis" ]; then
  "$makensis" -V2 -DVERSION="$version" -DEXE="$PWD/dist/stage/$name.exe" -DOUT="$PWD/dist/$name-$version-setup.exe" installer/installer.nsi
  sign "dist/$name-$version-setup.exe"
else
  echo "makensis not found: skipped the installer (apt install nsis)" >&2
fi
rm -rf dist/stage
ls -lh dist
