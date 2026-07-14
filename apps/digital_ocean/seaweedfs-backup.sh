#!/bin/bash
# Snapshots the Filer data directory. SeaweedFS is briefly stopped to get a consistent archive.

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
DROPLET_IP="68.183.219.251"
DROPLET_USER="root"
DATA_DIR="/var/lib/seaweedfs"
BACKUP_DIR="backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/seaweedfs_${TIMESTAMP}.tar.gz"
REMOTE_TMP="/tmp/seaweedfs_backup_${TIMESTAMP}.tar.gz"

echo "=== Premiere Ecoute SeaweedFS Backup Script ==="
echo ""

mkdir -p "${BACKUP_DIR}"

echo -e "${YELLOW}Backing up SeaweedFS from: ${DROPLET_USER}@${DROPLET_IP}${NC}"
echo -e "${YELLOW}Data dir: ${DATA_DIR}${NC}"
echo ""

# Stop briefly for a consistent snapshot, archive, then restart.
echo "Step 1: Creating consistent archive on droplet (brief downtime)..."
ssh ${DROPLET_USER}@${DROPLET_IP} "
    set -e
    systemctl stop seaweedfs
    tar czf '${REMOTE_TMP}' -C \"\$(dirname ${DATA_DIR})\" \"\$(basename ${DATA_DIR})\"
    systemctl start seaweedfs
"

echo "Step 2: Downloading archive..."
scp ${DROPLET_USER}@${DROPLET_IP}:"${REMOTE_TMP}" "${BACKUP_FILE}"
ssh ${DROPLET_USER}@${DROPLET_IP} "rm -f '${REMOTE_TMP}'"

if [ -f "${BACKUP_FILE}" ]; then
    BACKUP_SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
    echo -e "${GREEN}✓ SeaweedFS backup completed successfully${NC}"
    echo ""
    echo "Backup details:"
    echo "  - File: ${BACKUP_FILE}"
    echo "  - Size: ${BACKUP_SIZE}"
    echo ""
    echo "To restore this backup:"
    echo "  ./seaweedfs-restore.sh ${BACKUP_FILE}"
else
    echo -e "${RED}✗ SeaweedFS backup failed${NC}"
    exit 1
fi
