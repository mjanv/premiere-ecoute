set dotenv-load

default:
    just --list

# Name, port and suffix of this checkout (same rules as PremiereEcoute.MixProject.worktree/0 in mix.exs)
wt := '''
set -euo pipefail
name="${PE_WORKTREE:-$([ -f .git ] && basename "$PWD" || true)}"
name=$(printf %s "$name" | tr 'A-Z' 'a-z' | sed -E 's/[^a-z0-9]+/_/g; s/^_+|_+$//g' | cut -c1-24)
suffix="${name:+_$name}"
if [ -n "${PE_PORT:-}" ]; then port="$PE_PORT"
elif [ -n "$name" ]; then port=$((4000 + 10 * (16#$(printf %s "$name" | md5sum | cut -c1-8) % 90 + 1)))
else port=4000; fi
'''

# Start development server
server:
    #!/usr/bin/env bash
    {{wt}}
    docker compose up -d
    echo "==> http://localhost:$port (node dev$suffix)"
    exec iex --sname "dev$suffix" -S mix phx.server

# Connect to development server
connect:
    #!/usr/bin/env bash
    {{wt}}
    exec iex --remsh "dev$suffix" --sname "local$suffix"

# Show this checkout's name, port and suffix
info:
    #!/usr/bin/env bash
    {{wt}}
    echo "name: ${name:-<original checkout>}  web: http://localhost:$port  mock: $((port + 1))  test: $((port + 2))  node: dev$suffix"

# Drop a worktree's databases and remove it
worktree-remove name:
    cd .claude/worktrees/{{name}} && for e in dev test; do MIX_ENV=$e mix do event_store.drop --quiet + ecto.drop --quiet; done
    git worktree remove --force .claude/worktrees/{{name}}

# Show latest available version of each tool in .tool-versions
outdated:
    #!/usr/bin/env bash
    while read -r plugin version _; do
      latest=$(asdf latest "$plugin")
      printf '%-15s %s -> %s\n' "$plugin" "$version" "$latest"
    done < .tool-versions
    mix hex.outdated

# SSH in production server
ssh:
    ssh $SERVER

# Watch productions logs
watch:
    ssh $SERVER 'journalctl -u premiere-ecoute --since today -f'

# Connect to remote console
remote:
    echo "/opt/premiere-ecoute/bin/premiere_ecoute remote"
    ssh $SERVER 

# Start the application
start:
    ssh $SERVER 'systemctl start premiere-ecoute'

# Restart the application
restart:
    ssh $SERVER 'systemctl restart premiere-ecoute'

# Stop the application
stop:
    ssh $SERVER 'systemctl stop premiere-ecoute'

# Snapshot database
snapshot:
    ssh $SERVER 'sudo -u postgres pg_dump premiere_ecoute_prod | gzip' > backup_$(date +%Y%m%d_%H%M%S).sql.gz