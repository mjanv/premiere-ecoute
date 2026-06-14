#!/bin/bash
# AIDEV-NOTE: Creates an isolated staging environment from a live copy of production data.
# Usage: ./apps/digital_ocean/staging-create.sh
# Prerequisites: .env.staging must exist at the project root (copy from .env.staging.example)

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

DROPLET_IP="68.183.219.251"
DROPLET_USER="root"
STAGING_DIR="/opt/premiere-ecoute-staging"
APP_USER="premiere"
STAGING_SERVICE="premiere-ecoute-staging"
STAGING_DB="premiere_ecoute_staging"
PROD_DB="premiere_ecoute_prod"
DB_USER="postgres"

run_remote() {
    ssh ${DROPLET_USER}@${DROPLET_IP} "$@"
}

echo "=== Premiere Ecoute Staging Create ==="
echo ""

cd "$(dirname "$0")/../.."

if [ ! -f ".env.staging" ]; then
    echo -e "${RED}ERROR: .env.staging not found at project root.${NC}"
    echo "Copy apps/digital_ocean/.env.staging.example to .env.staging and fill in values."
    exit 1
fi

echo -e "${YELLOW}Target: ${DROPLET_USER}@${DROPLET_IP}${NC}"
echo -e "${YELLOW}Staging DB: ${STAGING_DB} (copy of ${PROD_DB})${NC}"
echo -e "${YELLOW}Staging URL: https://staging.premiere-ecoute.fr${NC}"
echo ""

# Step 1: Build release
echo "Step 1: Building release locally..."
export MIX_ENV=prod
mix deps.get --only prod
mix assets.deploy
mix release --overwrite
echo -e "${GREEN}✓ Release built${NC}"
echo ""

# Step 2: Clone production database
echo "Step 2: Cloning production database to staging..."
run_remote "
    set -e
    # Terminate any existing connections to staging DB before dropping
    sudo -u ${DB_USER} psql -c \"SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${STAGING_DB}' AND pid <> pg_backend_pid();\" 2>/dev/null || true
    sudo -u ${DB_USER} psql -c 'DROP DATABASE IF EXISTS ${STAGING_DB};'
    sudo -u ${DB_USER} psql -c 'CREATE DATABASE ${STAGING_DB};'
    # Dump prod (both public and event_store schemas) and restore into staging
    # --no-privileges and --no-owner so the staging DB uses the same postgres user
    sudo -u ${DB_USER} pg_dump --no-privileges --no-owner ${PROD_DB} | sudo -u ${DB_USER} psql -d ${STAGING_DB} -q
    echo 'Database cloned'
"
echo -e "${GREEN}✓ Database cloned${NC}"
echo ""

# Step 3: Deploy release to staging directory
echo "Step 3: Deploying release to ${STAGING_DIR}..."
run_remote "mkdir -p ${STAGING_DIR}"
rsync -avzq --delete --exclude='.env' --exclude='cache' \
    _build/prod/rel/premiere_ecoute/ ${DROPLET_USER}@${DROPLET_IP}:${STAGING_DIR}/
echo -e "${GREEN}✓ Release synced${NC}"
echo ""

# Step 4: Deploy config and systemd service
echo "Step 4: Deploying staging config..."
scp .env.staging ${DROPLET_USER}@${DROPLET_IP}:${STAGING_DIR}/.env
scp apps/digital_ocean/systemd/${STAGING_SERVICE}.service \
    ${DROPLET_USER}@${DROPLET_IP}:/etc/systemd/system/
scp apps/digital_ocean/traefik/dynamic.yml \
    ${DROPLET_USER}@${DROPLET_IP}:/opt/traefik/dynamic.yml
echo -e "${GREEN}✓ Config deployed${NC}"
echo ""

# Step 5: Fix permissions, reload systemd, and start the service
# ExecStartPre runs migrations against premiere_ecoute_staging
echo "Step 5: Starting staging service (migrations will run on startup)..."
run_remote "
    chown -R ${APP_USER}:${APP_USER} ${STAGING_DIR}
    find ${STAGING_DIR} \( -path '*/bin/*' -o -path '*/priv/bin/*' -o -name '*.so' \) -type f -exec chmod +x {} \;
    systemctl daemon-reload
    systemctl start ${STAGING_SERVICE}
"
echo -e "${GREEN}✓ Service started${NC}"
echo ""

echo "Step 6: Checking status..."
run_remote "systemctl status ${STAGING_SERVICE} --no-pager -l"
echo ""

echo -e "${GREEN}=== Staging is up ===${NC}"
echo ""
echo "  URL:  https://staging.premiere-ecoute.fr"
echo "  Logs: ssh root@${DROPLET_IP} 'journalctl -u ${STAGING_SERVICE} -f'"
echo ""
echo "When done, tear down with:"
echo "  ./apps/digital_ocean/staging-destroy.sh"
