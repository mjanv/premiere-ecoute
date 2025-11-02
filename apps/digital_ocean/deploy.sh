#!/bin/bash
# AIDEV-NOTE: Native deployment script for Digital Ocean droplet (no Docker)

set -e

echo "=== Premiere Ecoute Native Deployment Script ==="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DROPLET_IP="68.183.219.251"
DROPLET_USER="root"
DEPLOY_DIR="/opt/premiere-ecoute"
APP_USER="premiere"

echo -e "${YELLOW}Deploying to: ${DROPLET_USER}@${DROPLET_IP}${NC}"
echo ""

# Function to run commands on the droplet
run_remote() {
    ssh ${DROPLET_USER}@${DROPLET_IP} "$@"
}

# Check if .env.production exists locally
if [ ! -f ".env.production" ]; then
    echo -e "${RED}ERROR: .env.production file not found!${NC}"
    echo "Please create .env.production from .env.production.example"
    exit 1
fi

echo "Step 1: Building release locally..."
cd "$(dirname "$0")/../.."
export MIX_ENV=prod
mix deps.get --only prod
mix assets.deploy
mix release --overwrite

echo "Step 2: Creating deployment directory on droplet..."
run_remote "mkdir -p ${DEPLOY_DIR}"

echo "Step 3: Copying release to droplet..."
# AIDEV-NOTE: Exclude .env from deletion to preserve production environment variables
rsync -avz --delete --exclude='.env' _build/prod/rel/premiere_ecoute/ ${DROPLET_USER}@${DROPLET_IP}:${DEPLOY_DIR}/

echo "Step 4: Copying configuration files..."
# AIDEV-NOTE: Use .env.production for production deployments
# Copy .env.production to server as .env (contains production URLs and config)
if [ ! -f ".env.production" ]; then
    echo -e "${RED}ERROR: .env.production file not found!${NC}"
    echo "Please create .env.production from .env.production.example"
    exit 1
fi
scp .env.production ${DROPLET_USER}@${DROPLET_IP}:${DEPLOY_DIR}/.env
rsync -avz apps/digital_ocean/systemd/ ${DROPLET_USER}@${DROPLET_IP}:/tmp/systemd/
rsync -avz apps/digital_ocean/traefik/ ${DROPLET_USER}@${DROPLET_IP}:/tmp/traefik/

echo "Step 5: Setting up server (if first deployment)..."
run_remote "bash -s" < apps/digital_ocean/setup.sh

echo "Step 6: Installing systemd services..."
run_remote "
    # Copy systemd service files
    cp /tmp/systemd/premiere-ecoute.service /etc/systemd/system/
    cp /tmp/systemd/traefik.service /etc/systemd/system/

    # Setup Traefik config
    mkdir -p /opt/traefik
    cp /tmp/traefik/traefik.yml /opt/traefik/
    cp /tmp/traefik/dynamic.yml /opt/traefik/
    touch /opt/traefik/acme.json
    chmod 600 /opt/traefik/acme.json
    chown -R traefik:traefik /opt/traefik

    # Set permissions
    chown -R ${APP_USER}:${APP_USER} ${DEPLOY_DIR}

    # Reload systemd
    systemctl daemon-reload
"

echo "Step 7: Starting/Restarting services..."
run_remote "
    # Start PostgreSQL if not running
    systemctl start postgresql
    systemctl enable postgresql

    # Start/restart Traefik
    systemctl restart traefik
    systemctl enable traefik

    # Start/restart application
    systemctl restart premiere-ecoute
    systemctl enable premiere-ecoute
"

echo "Step 8: Checking service status..."
run_remote "
    echo '=== Service Status ==='
    systemctl status postgresql --no-pager -l || true
    echo ''
    systemctl status traefik --no-pager -l || true
    echo ''
    systemctl status premiere-ecoute --no-pager -l || true
"

echo ""
echo -e "${GREEN}Deployment completed successfully!${NC}"
echo ""
echo "Access your application at:"
echo "  - HTTP:  http://${DROPLET_IP} (redirects to HTTPS)"
echo "  - HTTPS: https://${DROPLET_IP}"
echo ""
echo "Useful commands:"
echo "  - View app logs: ssh ${DROPLET_USER}@${DROPLET_IP} 'journalctl -u premiere-ecoute -f'"
echo "  - View traefik logs: ssh ${DROPLET_USER}@${DROPLET_IP} 'journalctl -u traefik -f'"
echo "  - Restart app: ssh ${DROPLET_USER}@${DROPLET_IP} 'systemctl restart premiere-ecoute'"
echo "  - Check status: ssh ${DROPLET_USER}@${DROPLET_IP} 'systemctl status premiere-ecoute'"
