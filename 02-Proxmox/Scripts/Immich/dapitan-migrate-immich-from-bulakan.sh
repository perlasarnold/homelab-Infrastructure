#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================================================================
# Script: dapitan-migrate-immich-from-bulakan.sh
# Purpose: Non-disruptive migration of Immich media library assets and PostgreSQL
#          database metadata from Bulakan (VM 204) to Dapitan CT 504 (18TB Storage).
#
# Workflow Steps:
# 1. Mount Bulakan VM 204 ZFS volume partition read-only (-o ro).
# 2. Rsync all Immich library assets (224.4 GB) to Dapitan's bulk18/immich-data.
# 3. Extract and restore daily PostgreSQL database dump into immich_postgres.
# 4. Bring up full Immich stack (server, machine learning, postgres, redis).
# ==============================================================================

BULAKAN_HOST="${BULAKAN_HOST:-192.168.1.25}"
DAPITAN_HOST="${DAPITAN_HOST:-192.168.1.27}"
SOURCE_ZVOL="${SOURCE_ZVOL:-/dev/zvol/Bulakan-ZFS/vm-204-disk-0-part2}"
TEMP_MOUNT="${TEMP_MOUNT:-/mnt/immich-vm-temp}"
TARGET_DATA_DIR="${TARGET_DATA_DIR:-/mnt/bindmounts/immich-data}"
CT_ID="${CT_ID:-504}"

log() {
  printf '[%s] %s\n' "$(date --iso-8601=seconds)" "$*"
}

fail() {
  log "ERROR: $*"
  exit 1
}

log "=== Starting Immich Migration from Bulakan to Dapitan ==="

# Step 1: Mount Bulakan VM 204 partition read-only on Bulakan host
log "Step 1: Mounting Bulakan VM 204 partition read-only on Bulakan host (${BULAKAN_HOST})..."
ssh "root@${BULAKAN_HOST}" "mkdir -p ${TEMP_MOUNT} && mountpoint -q ${TEMP_MOUNT} || mount -o ro ${SOURCE_ZVOL} ${TEMP_MOUNT}"

# Step 2: Rsync photo/video library assets to Dapitan 18TB storage
log "Step 2: Syncing Immich assets from Bulakan to Dapitan (${TARGET_DATA_DIR})..."
ssh "root@${BULAKAN_HOST}" "rsync -av --info=progress2 ${TEMP_MOUNT}/home/homelab-admin/immich-app/mnt/immich-nas/ root@${DAPITAN_HOST}:${TARGET_DATA_DIR}/"

# Step 3: Unmount temporary read-only partition on Bulakan host
log "Step 3: Unmounting temporary read-only partition on Bulakan host..."
ssh "root@${BULAKAN_HOST}" "mountpoint -q ${TEMP_MOUNT} && umount ${TEMP_MOUNT} || true"

# Step 4: Restore PostgreSQL database dump inside CT 504 on Dapitan host
log "Step 4: Restoring PostgreSQL database dump inside CT ${CT_ID} on Dapitan host..."
ssh "root@${DAPITAN_HOST}" "pct exec ${CT_ID} -- bash -c '
  cd /opt/immich
  docker compose up -d database redis
  gunzip -c /mnt/immich-nas/backups/immich-db-backup-*.sql.gz | tail -n 1 > /tmp/latest-backup.sql || true
  LATEST_BACKUP=\$(ls -t /mnt/immich-nas/backups/immich-db-backup-*.sql.gz | head -n 1)
  echo \"Decompressing \${LATEST_BACKUP}...\"
  gunzip -c \"\${LATEST_BACKUP}\" > /tmp/immich-db-backup.sql
  docker exec immich_postgres dropdb --if-exists -U postgres immich
  docker exec immich_postgres createdb -O postgres -U postgres immich
  echo \"Restoring SQL database schema and records...\"
  docker exec -i immich_postgres psql -U postgres -d immich < /tmp/immich-db-backup.sql
  echo \"Starting full Immich stack...\"
  docker compose up -d
'"

log "=== Immich Migration Completed Successfully ==="
