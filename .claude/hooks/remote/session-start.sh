#!/bin/bash
# SessionStart hook

cd "$CLAUDE_PROJECT_DIR" || exit 0

# Linked git worktree (e.g. `claude --worktree`): own database, ports and node name (mix.exs).
if [ -f .git ]; then
  if [ ! -e .wt-ready ]; then
    echo "==> Setting up git worktree database..."
    mix setup && touch .wt-ready
  fi
  # Point the project MCP servers (.mcp.json uses ${PE_PORT:-4000}) at this worktree's app.
  # Same rules as PremiereEcoute.MixProject.worktree/0 in mix.exs and the .justfile.
  name="${PE_WORKTREE:-$(basename "$PWD")}"
  name=$(printf %s "$name" | tr 'A-Z' 'a-z' | sed -E 's/[^a-z0-9]+/_/g; s/^_+|_+$//g' | cut -c1-24)
  if [ -n "${PE_PORT:-}" ]; then port="$PE_PORT"
  else port=$((4000 + 10 * (16#$(printf %s "$name" | md5sum | cut -c1-8) % 90 + 1))); fi
  settings=.claude/settings.local.json
  [ -f "$settings" ] || echo '{}' >"$settings"
  jq --arg port "$port" '.env.PE_PORT = $port' "$settings" >"$settings.tmp" && mv "$settings.tmp" "$settings"
fi

# Cloud-only: start PostgreSQL and prepare the test database
if [ "$CLAUDE_CODE_REMOTE" = "true" ]; then
  echo "==> Loading Erlang/Elixir PATH..."
  if [ -f /etc/profile.d/elixir.sh ]; then
    . /etc/profile.d/elixir.sh
  fi

  if ! command -v mix >/dev/null 2>&1; then
    echo "==> mix not found (setup-script install did not persist) — installing Elixir/OTP now..."
    curl -fsSO https://elixir-lang.org/install.sh
    sh install.sh elixir@1.20.4 otp@29.1.1
    rm install.sh

    installs_dir="$HOME/.elixir-install/installs"
    otp_bin=$(echo "$installs_dir"/otp/29.1.1/bin)
    elixir_bin=$(echo "$installs_dir"/elixir/1.20.4-otp-*/bin)
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
