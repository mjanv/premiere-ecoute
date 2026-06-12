#!/bin/bash
set -euo pipefail

# The base image ships broken third-party PPA sources (deadsnakes, ondrej/php) that
# 403/unsigned upstream and abort `apt-get update` outright. Disable any apt source
# file referencing them before updating — this script only needs Ubuntu's main archive.
for f in /etc/apt/sources.list.d/*; do
  if grep -lqE 'launchpadcontent\.net/(deadsnakes|ondrej)/' "$f" 2>/dev/null; then
    mv "$f" "$f.disabled"
  fi
done

apt-get update -qq
apt-get install -y --no-install-recommends libssl3 libsctp1 curl unzip ca-certificates

# Official Elixir installer (elixir-lang.org/install.sh) — fetches precompiled OTP and
# Elixir binaries over plain HTTPS (github.com release assets + builds.hex.pm), no git
# clone. This sandbox's proxy 403s on the git protocol against github.com but allows
# plain HTTPS downloads, so this avoids asdf/git entirely.
curl -fsSO https://elixir-lang.org/install.sh
sh install.sh elixir@1.20.1 otp@29.0.2
rm install.sh

installs_dir="$HOME/.elixir-install/installs"
otp_bin=$(echo "$installs_dir"/otp/29.0.2/bin)
elixir_bin=$(echo "$installs_dir"/elixir/1.20.1-otp-*/bin)
echo "export PATH=\"$elixir_bin:$otp_bin:\$PATH\"" > /etc/profile.d/elixir.sh
export PATH="$elixir_bin:$otp_bin:$PATH"

mix local.hex --force --if-missing
mix local.rebar --force --if-missing
