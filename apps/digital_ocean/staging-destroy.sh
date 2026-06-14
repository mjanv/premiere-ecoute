#!/bin/bash
# AIDEV-NOTE: Tears down the staging environment: stops the service, drops the DB, removes files.
# Usage: ./apps/digital_ocean/staging-destroy.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

DROPLET_IP="68.183.219.251"
DROPLET_USER="root"
STAGING_DIR="/opt/premiere-ecoute-staging"
STAGING_SERVICE="premiere-ecoute-staging"
STAGING_DB="premiere_ecoute_staging"
DB_USER="postgres"

run_remote() {
    ssh ${DROPLET_USER}@${DROPLET_IP} "$@"
}

echo "=== Premiere Ecoute Staging Destroy ==="
echo ""
echo -e "${YELLOW}This will stop the staging service, drop ${STAGING_DB}, and delete ${STAGING_DIR}.${NC}"
read -r -p "Continue? [y/N] " confirm
if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
    echo "Aborted."
    exit 0
fi
echo ""

# Step 1: Stop and remove the systemd service
echo "Step 1: Stopping staging service..."
run_remote "
    systemctl stop ${STAGING_SERVICE} 2>/dev/null || true
    systemctl disable ${STAGING_SERVICE} 2>/dev/null || true
    rm -f /etc/systemd/system/${STAGING_SERVICE}.service
    systemctl daemon-reload
    echo 'Service stopped and removed'
"
echo -e "${GREEN}✓ Service removed${NC}"
echo ""

# Step 2: Drop the staging database
echo "Step 2: Dropping staging database..."
run_remote "
    # Terminate any remaining connections first
    sudo -u ${DB_USER} psql -c \"SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${STAGING_DB}' AND pid <> pg_backend_pid();\" 2>/dev/null || true
    sudo -u ${DB_USER} psql -c 'DROP DATABASE IF EXISTS ${STAGING_DB};'
    echo 'Database dropped'
"
echo -e "${GREEN}✓ Database dropped${NC}"
echo ""

# Step 3: Remove staging directory
echo "Step 3: Removing staging directory..."
run_remote "rm -rf ${STAGING_DIR} && echo 'Directory removed'"
echo -e "${GREEN}✓ Directory removed${NC}"
echo ""

echo -e "${GREEN}=== Staging environment destroyed ===${NC}"
