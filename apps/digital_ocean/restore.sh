#!/bin/bash
# AIDEV-NOTE: Database restore script for Digital Ocean droplet

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DROPLET_IP="68.183.219.251"
DROPLET_USER="root"
DB_NAME="premiere_ecoute_prod"
DB_USER="postgres"

echo "=== Premiere Ecoute Database Restore Script ==="
echo ""

# Check if backup file is provided
if [ -z "$1" ]; then
    echo -e "${RED}ERROR: No backup file specified${NC}"
    echo ""
    echo "Usage: $0 <backup_file>"
    echo ""
    echo "Available backups:"
    ls -lh backups/*.sql.gz 2>/dev/null || echo "  No backups found in backups/ directory"
    exit 1
fi

BACKUP_FILE="$1"

# Check if backup file exists
if [ ! -f "${BACKUP_FILE}" ]; then
    echo -e "${RED}ERROR: Backup file not found: ${BACKUP_FILE}${NC}"
    exit 1
fi

echo -e "${YELLOW}Restoring database to: ${DROPLET_USER}@${DROPLET_IP}${NC}"
echo -e "${YELLOW}Database: ${DB_NAME}${NC}"
echo -e "${YELLOW}Backup file: ${BACKUP_FILE}${NC}"
echo ""

# Check if file is compressed
if [[ "${BACKUP_FILE}" == *.gz ]]; then
    SQL_FILE="${BACKUP_FILE%.gz}"
    echo "Step 1: Decompressing backup..."
    gunzip -c "${BACKUP_FILE}" > "${SQL_FILE}"
    echo -e "${GREEN}✓ Backup decompressed${NC}"
    echo ""
    CLEANUP_SQL=true
else
    SQL_FILE="${BACKUP_FILE}"
    CLEANUP_SQL=false
fi

# Confirm before proceeding
echo -e "${RED}WARNING: This will DROP and recreate the production database!${NC}"
echo -e "${RED}All existing data will be LOST!${NC}"
echo ""
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Restore cancelled."
    if [ "$CLEANUP_SQL" = true ]; then
        rm -f "${SQL_FILE}"
    fi
    exit 0
fi

echo ""
echo "Step 2: Stopping application..."
ssh ${DROPLET_USER}@${DROPLET_IP} "systemctl stop premiere-ecoute"
echo -e "${GREEN}✓ Application stopped${NC}"
echo ""

echo "Step 3: Uploading backup to droplet..."
scp "${SQL_FILE}" ${DROPLET_USER}@${DROPLET_IP}:/tmp/restore.sql
echo -e "${GREEN}✓ Backup uploaded${NC}"
echo ""

echo "Step 4: Dropping existing database..."
ssh ${DROPLET_USER}@${DROPLET_IP} "sudo -u postgres psql -c 'DROP DATABASE IF EXISTS ${DB_NAME};'"
echo -e "${GREEN}✓ Database dropped${NC}"
echo ""

echo "Step 5: Creating fresh database..."
ssh ${DROPLET_USER}@${DROPLET_IP} "sudo -u postgres psql -c 'CREATE DATABASE ${DB_NAME};'"
echo -e "${GREEN}✓ Database created${NC}"
echo ""

echo "Step 6: Restoring database from backup..."
ssh ${DROPLET_USER}@${DROPLET_IP} "sudo -u postgres psql -d ${DB_NAME} < /tmp/restore.sql"
echo -e "${GREEN}✓ Database restored${NC}"
echo ""

echo "Step 7: Cleaning up temporary files..."
ssh ${DROPLET_USER}@${DROPLET_IP} "rm -f /tmp/restore.sql"
if [ "$CLEANUP_SQL" = true ]; then
    rm -f "${SQL_FILE}"
fi
echo -e "${GREEN}✓ Cleanup completed${NC}"
echo ""

echo "Step 8: Starting application..."
ssh ${DROPLET_USER}@${DROPLET_IP} "systemctl start premiere-ecoute"
echo -e "${GREEN}✓ Application started${NC}"
echo ""

echo "Step 9: Checking service status..."
ssh ${DROPLET_USER}@${DROPLET_IP} "systemctl status premiere-ecoute --no-pager -l | head -20"
echo ""

echo -e "${GREEN}Database restore completed successfully!${NC}"
echo ""
echo "Verify the application at: https://${DROPLET_IP}"
