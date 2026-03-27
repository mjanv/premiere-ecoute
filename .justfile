default:
    just --list

# Start development server
server:
    docker compose up -d
    iex -S mix phx.server

# Watch productions logs
watch:
    ssh root@68.183.219.251 'journalctl -u premiere-ecoute -f'

# Restart the application
restart:
    ssh root@68.183.219.251 'systemctl restart premiere-ecoute'

# Snapshot database
snapshot:
    ssh root@68.183.219.251 'sudo -u postgres pg_dump premiere_ecoute_prod | gzip' > backup_$(date +%Y%m%d_%H%M%S).sql.gz