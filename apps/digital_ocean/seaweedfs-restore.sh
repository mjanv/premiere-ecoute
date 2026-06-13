#!/bin/bash
# AIDEV-NOTE: SeaweedFS (podcast storage) restore script for Digital Ocean droplet.
# Replaces the Filer data directory with the contents of a backup archive. DESTRUCTIVE.

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
DROPLET_IP="68.183.219.251"
DROPLET_USER="root"
DATA_DIR="/var/lib/seaweedfs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REMOTE_TMP="/tmp/seaweedfs_restore_${TIMESTAMP}.tar.gz"

echo "=== Premiere Ecoute SeaweedFS Restore Script ==="
echo ""

if [ -z "$1" ]; then
    echo -e "${RED}ERROR: No backup file specified${NC}"
    echo ""
    echo "Usage: $0 <backup_file>"
    echo ""
    echo "Available backups:"
    ls -lh backups/seaweedfs_*.tar.gz 2>/dev/null || echo "  No backups found in backups/ directory"
    exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "${BACKUP_FILE}" ]; then
    echo -e "${RED}ERROR: Backup file not found: ${BACKUP_FILE}${NC}"
    exit 1
fi

echo -e "${YELLOW}Restoring SeaweedFS to: ${DROPLET_USER}@${DROPLET_IP}${NC}"
echo -e "${YELLOW}This will REPLACE the current data in ${DATA_DIR}.${NC}"
read -p "Type 'yes' to continue: " CONFIRM
[ "${CONFIRM}" = "yes" ] || { echo "Aborted."; exit 1; }

echo "Step 1: Uploading archive..."
scp "${BACKUP_FILE}" ${DROPLET_USER}@${DROPLET_IP}:"${REMOTE_TMP}"

echo "Step 2: Stopping SeaweedFS, replacing data, restarting..."
ssh ${DROPLET_USER}@${DROPLET_IP} "
    set -e
    systemctl stop seaweedfs
    rm -rf '${DATA_DIR}'
    tar xzf '${REMOTE_TMP}' -C \"\$(dirname ${DATA_DIR})\"
    chown -R seaweedfs:seaweedfs '${DATA_DIR}'
    systemctl start seaweedfs
    rm -f '${REMOTE_TMP}'
"

echo -e "${GREEN}✓ SeaweedFS restore completed successfully${NC}"
