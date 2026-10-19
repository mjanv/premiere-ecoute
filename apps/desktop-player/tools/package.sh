#!/usr/bin/env bash
# Build the release exe and package it for people: dist/<name>-<version>-setup.exe (installer) and dist/<name>-<version>-portable.zip.
# usage: tools/package.sh          (needs cargo-xwin; makensis from `apt install nsis`, or NSISDIR + MAKENSIS set)
set -euo pipefail
cd "$(dirname "$0")/.."
name=premiere-ecoute-player
version=$(sed -n 's/^version = "\(.*\)"/\1/p' Cargo.toml | head -1)
target=x86_64-pc-windows-msvc
exe=target/$target/release/$name.exe

cargo xwin build --target $target --release

rm -rf dist && mkdir -p dist
cp "$exe" "dist/$name.exe"
(cd dist && zip -q "$name-$version-portable.zip" "$name.exe" && rm "$name.exe")

makensis=${MAKENSIS:-$(command -v makensis || true)}
if [ -n "$makensis" ]; then
  "$makensis" -V2 -DVERSION="$version" -DEXE="$PWD/$exe" -DOUT="$PWD/dist/$name-$version-setup.exe" installer/installer.nsi
else
  echo "makensis not found: skipped the installer (apt install nsis)" >&2
fi
ls -lh dist
