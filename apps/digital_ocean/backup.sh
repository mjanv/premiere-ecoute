#!/bin/bash
# AIDEV-NOTE: Database backup script for Digital Ocean droplet

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
BACKUP_DIR="backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/premiere_ecoute_${TIMESTAMP}.sql"

echo "=== Premiere Ecoute Database Backup Script ==="
echo ""

# Create backup directory if it doesn't exist
mkdir -p "${BACKUP_DIR}"

echo -e "${YELLOW}Backing up database from: ${DROPLET_USER}@${DROPLET_IP}${NC}"
echo -e "${YELLOW}Database: ${DB_NAME}${NC}"
echo ""

# Dump database from droplet
echo "Step 1: Dumping database on droplet..."
ssh ${DROPLET_USER}@${DROPLET_IP} "sudo -u postgres pg_dump ${DB_NAME}" > "${BACKUP_FILE}"

if [ $? -eq 0 ]; then
    BACKUP_SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
    echo -e "${GREEN}✓ Database backup completed successfully${NC}"
    echo ""
    echo "Backup details:"
    echo "  - File: ${BACKUP_FILE}"
    echo "  - Size: ${BACKUP_SIZE}"
    echo ""

    # Show backup statistics
    echo "Backup statistics:"
    echo "  - Lines: $(wc -l < "${BACKUP_FILE}")"
    echo "  - Tables: $(grep -c "CREATE TABLE" "${BACKUP_FILE}" || echo "0")"
    echo "  - INSERT statements: $(grep -c "^INSERT INTO" "${BACKUP_FILE}" || echo "0")"
    echo "  - COPY statements: $(grep -c "^COPY" "${BACKUP_FILE}" || echo "0")"
    echo ""

    # Compress backup
    echo "Step 2: Compressing backup..."
    gzip "${BACKUP_FILE}"
    COMPRESSED_FILE="${BACKUP_FILE}.gz"
    COMPRESSED_SIZE=$(du -h "${COMPRESSED_FILE}" | cut -f1)
    echo -e "${GREEN}✓ Backup compressed${NC}"
    echo "  - Compressed file: ${COMPRESSED_FILE}"
    echo "  - Compressed size: ${COMPRESSED_SIZE}"
    echo ""

    echo -e "${GREEN}Backup completed successfully!${NC}"
    echo ""
    echo "To restore this backup:"
    echo "  gunzip ${COMPRESSED_FILE}"
    echo "  psql -U postgres -d ${DB_NAME} < ${BACKUP_FILE}"
else
    echo -e "${RED}✗ Database backup failed${NC}"
    exit 1
fi
