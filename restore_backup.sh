#!/bin/bash

# Odoo Database Restore Script
# Usage: ./restore_backup.sh <backup_file.zip>

set -e

BACKUP_FILE=$1
DB_NAME="elantar_odoo"
DB_USER="odoo"
DB_PASSWORD="qwerty76%&/"
DB_CONTAINER="odoo_db"
ODOO_CONTAINER="elantar_odoo"
BACKUP_DIR="/tmp/odoo_restore_$(date +%Y%m%d_%H%M%S)"

if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 <backup_file.zip>"
    echo "Example: $0 /opt/odoo-backup/backupszip/elantar_odoo_20251123_023001.zip"
    exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
    echo "Error: Backup file not found: $BACKUP_FILE"
    exit 1
fi

echo "=========================================="
echo "Odoo Database Restore Process"
echo "=========================================="
echo "Backup file: $BACKUP_FILE"
echo "Database: $DB_NAME"
echo ""

# Step 1: Stop Odoo container
echo "[1/7] Stopping Odoo container..."
docker stop $ODOO_CONTAINER || echo "Container already stopped"
echo "✓ Odoo container stopped"
echo ""

# Step 2: Extract backup
echo "[2/7] Extracting backup file..."
mkdir -p $BACKUP_DIR
cd $BACKUP_DIR
unzip -q "$BACKUP_FILE"
echo "✓ Backup extracted to $BACKUP_DIR"
echo ""

# Step 3: Drop existing database
echo "[3/7] Dropping existing database (if exists)..."
docker exec -i $DB_CONTAINER psql -U $DB_USER -d postgres -c "DROP DATABASE IF EXISTS $DB_NAME;" || true
echo "✓ Database dropped"
echo ""

# Step 4: Create new database
echo "[4/7] Creating new database..."
docker exec -i $DB_CONTAINER psql -U $DB_USER -d postgres -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"
echo "✓ Database created"
echo ""

# Step 5: Restore PostgreSQL dump
echo "[5/7] Restoring PostgreSQL dump (this may take a few minutes)..."
docker exec -i $DB_CONTAINER pg_restore -U $DB_USER -d $DB_NAME --no-owner --no-acl < elantar_odoo.dump
echo "✓ Database dump restored"
echo ""

# Step 6: Restore filestore
echo "[6/7] Restoring filestore..."
FILESTORE_SOURCE="$BACKUP_DIR/filestore/elantar_odoo"
if [ -d "$FILESTORE_SOURCE" ]; then
    # Start container temporarily to create directory and copy files
    docker start $ODOO_CONTAINER
    sleep 2
    # Create filestore directory if it doesn't exist
    docker exec $ODOO_CONTAINER mkdir -p /var/lib/odoo/filestore
    # Copy filestore content
    docker cp "$FILESTORE_SOURCE/." ${ODOO_CONTAINER}:/var/lib/odoo/filestore/elantar_odoo/
    echo "✓ Filestore restored"
else
    echo "⚠ Filestore directory not found in backup"
fi
echo ""

# Step 7: Restart Odoo container (if not already running)
echo "[7/7] Restarting Odoo container..."
if [ "$(docker ps -q -f name=$ODOO_CONTAINER)" ]; then
    docker restart $ODOO_CONTAINER
else
    docker start $ODOO_CONTAINER
fi
echo "✓ Odoo container restarted"
echo ""

# Cleanup
echo "Cleaning up temporary files..."
rm -rf $BACKUP_DIR
echo "✓ Cleanup completed"
echo ""

echo "=========================================="
echo "Restore completed successfully!"
echo "=========================================="
echo "Database: $DB_NAME"
echo "Check logs with: docker logs $ODOO_CONTAINER --tail 50"
echo ""

