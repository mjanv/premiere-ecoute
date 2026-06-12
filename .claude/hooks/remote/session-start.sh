#!/bin/bash
# SessionStart hook

cd "$CLAUDE_PROJECT_DIR" || exit 0

# Cloud-only: start PostgreSQL and prepare the test database
if [ "$CLAUDE_CODE_REMOTE" = "true" ]; then
  echo "==> Loading Erlang/Elixir PATH..."
  if [ -f /etc/profile.d/elixir.sh ]; then
    . /etc/profile.d/elixir.sh
  fi

  if ! command -v mix >/dev/null 2>&1; then
    echo "==> mix not found (setup-script install did not persist) — installing Elixir/OTP now..."
    curl -fsSO https://elixir-lang.org/install.sh
    sh install.sh elixir@1.20.1 otp@29.0.2
    rm install.sh

    installs_dir="$HOME/.elixir-install/installs"
    otp_bin=$(echo "$installs_dir"/otp/29.0.2/bin)
    elixir_bin=$(echo "$installs_dir"/elixir/1.20.1-otp-*/bin)
    export PATH="$elixir_bin:$otp_bin:$PATH"

    mix local.hex --force --if-missing
    mix local.rebar --force --if-missing
  fi

  echo "==> Starting PostgreSQL..."
  service postgresql start || true

  echo "==> Setting postgres password..."
  su -c "psql -c \"ALTER USER postgres PASSWORD 'postgres';\" 2>/dev/null || true" postgres

  # Skip if deps/ was restored from the setup-script cache
  if [ ! -d deps ]; then
    echo "==> Installing Mix dependencies..."
    mix deps.get
  else
    echo "==> Mix dependencies already cached, skipping."
  fi

  echo "==> Setting up test database..."
  MIX_ENV=test mix ecto.setup || true

  echo "==> Cloud setup complete."
fi
