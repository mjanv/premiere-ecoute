set dotenv-load

default:
    just --list

# Start development server
server:
    docker compose up -d
    iex -S mix phx.server

# SSH in production server
ssh:
    ssh $SERVER

# Watch productions logs
watch:
    ssh $SERVER 'journalctl -u premiere-ecoute -f'

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