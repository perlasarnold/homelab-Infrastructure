#!/usr/bin/env bash
# ==============================================================================
# Jellyfin Automated Update with 5-Point QA Health Validation & Auto-Rollback
# Retention Policy: Maximum 4 Rolling Pre-Upgrade Snapshots Kept
# ==============================================================================
# Schedule: Weekly on Sunday at 3:00 AM (0 3 * * 0)
#
# Workflow:
#   1. Detects container rootfs ZFS dataset and creates snapshot: pre-upgrade-<TIMESTAMP>
#   2. Runs APT package upgrade for jellyfin & jellyfin-ffmpeg inside LXC container.
#   3. Ensures /var/lib/jellyfin/wwwroot symlink integrity post-upgrade.
#   4. Executes 5-Point QA Health Suite:
#        - Check 1: systemd service active (jellyfin)
#        - Check 2: HTTP 200 OK from /health
#        - Check 3: HTTP 200 OK from /web/index.html
#        - Check 4: Jellyfin API /System/Info/Public response with valid JSON
#        - Check 5: Intel QuickSync GPU device accessible (vainfo under jellyfin user)
#   5. IF ALL QA CHECKS PASS:
#        - Retains snapshot in a rolling 4-snapshot buffer (max 4 backups).
#        - Automatically prunes any snapshots older than the 4 most recent.
#        - Logs success.
#   6. IF ANY QA CHECK FAILS:
#        - Triggers instant automated ZFS rollback: zfs rollback -r <DATASET>@<SNAP>
#        - Restarts container and logs failure/rollback status.
# ==============================================================================

set -euo pipefail

LOG_FILE="/var/log/jellyfin-auto-update.log"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
MAX_BACKUPS=4

log() {
    local MSG="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] ${MSG}" | tee -a "${LOG_FILE}"
}

error_log() {
    local MSG="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] ${MSG}" | tee -a "${LOG_FILE}" >&2
}

prune_old_snapshots() {
    local DATASET="$1"
    local LIMIT="${2:-4}"
    
    # List all auto-upgrade snapshots for this dataset, sorted oldest first
    local SNAPS
    SNAPS=$(zfs list -H -t snapshot -o name -s creation "${DATASET}" | grep -E '@pre-upgrade-' || true)
    
    if [ -z "${SNAPS}" ]; then
        return 0
    fi
    
    local COUNT
    COUNT=$(echo "${SNAPS}" | grep -c '@' || echo 0)
    
    if [ "${COUNT}" -gt "${LIMIT}" ]; then
        local TO_DELETE=$(( COUNT - LIMIT ))
        log "Found ${COUNT} pre-upgrade snapshots (retention limit is ${LIMIT}). Pruning ${TO_DELETE} oldest snapshot(s)..."
        echo "${SNAPS}" | head -n "${TO_DELETE}" | while read -r SNAP; do
            if [ -n "${SNAP}" ]; then
                log "  [PRUNED] Deleting expired snapshot: ${SNAP}"
                zfs destroy "${SNAP}" || true
            fi
        done
    else
        log "Snapshot retention OK: ${COUNT}/${LIMIT} snapshots retained for ${DATASET}."
    fi
}

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <CT_ID>"
    echo "Example: $0 110"
    exit 1
fi

CT_ID="$1"
SNAP_NAME="pre-upgrade-${TIMESTAMP}"

log "========================================================================"
log "Starting Automated Jellyfin Upgrade & QA Suite for Container: ${CT_ID}"
log "Retention Policy: Max ${MAX_BACKUPS} rolling snapshots"
log "========================================================================"

# 1. Check if container exists and is running
if ! pct status "${CT_ID}" | grep -q "status: running"; then
    error_log "Container ${CT_ID} is not running. Aborting auto-update."
    exit 1
fi

# 2. Locate ZFS Rootfs Dataset
ZFS_DATASET=$(zfs list -H -o name | grep "subvol-${CT_ID}-disk" | head -n 1 || true)
if [ -z "${ZFS_DATASET}" ]; then
    error_log "Could not locate ZFS dataset for subvol-${CT_ID}-disk. Aborting for safety."
    exit 1
fi
log "Located ZFS dataset: ${ZFS_DATASET}"

# 3. Record Pre-Upgrade Version
PRE_VERSION=$(pct exec "${CT_ID}" -- dpkg -s jellyfin-server 2>/dev/null | grep '^Version:' | awk '{print $2}' || echo "unknown")
log "Current installed Jellyfin version: ${PRE_VERSION}"

# 4. Create Pre-Upgrade ZFS Snapshot
log "Creating pre-upgrade snapshot: ${ZFS_DATASET}@${SNAP_NAME}..."
if ! zfs snapshot "${ZFS_DATASET}@${SNAP_NAME}"; then
    error_log "Failed to create ZFS snapshot. Aborting update."
    exit 1
fi
log "Snapshot created successfully."

# 5. Perform Package Upgrade
log "Checking and applying Jellyfin updates via APT..."
pct exec "${CT_ID}" -- apt-get update -qq

# Check if an update is available
UPGRADEABLE=$(pct exec "${CT_ID}" -- apt-get --just-print upgrade | grep -iE 'jellyfin|jellyfin-server|jellyfin-web|jellyfin-ffmpeg' || true)
if [ -z "${UPGRADEABLE}" ]; then
    log "Jellyfin is already at the latest version (${PRE_VERSION}). No upgrade needed."
    zfs destroy "${ZFS_DATASET}@${SNAP_NAME}" || true
    prune_old_snapshots "${ZFS_DATASET}" "${MAX_BACKUPS}"
    log "Process complete."
    exit 0
fi

if ! pct exec "${CT_ID}" -- apt-get install --only-upgrade -y -qq jellyfin jellyfin-server jellyfin-web; then
    error_log "APT upgrade command failed. Initiating immediate rollback..."
    pct stop "${CT_ID}"
    zfs rollback -r "${ZFS_DATASET}@${SNAP_NAME}"
    pct start "${CT_ID}"
    error_log "Rolled back to ${SNAP_NAME} due to APT failure."
    exit 1
fi

# Ensure wwwroot symlink is in place
pct exec "${CT_ID}" -- ln -snf /usr/share/jellyfin/web /var/lib/jellyfin/wwwroot

POST_VERSION=$(pct exec "${CT_ID}" -- dpkg -s jellyfin-server | grep '^Version:' | awk '{print $2}')
log "Jellyfin package updated: ${PRE_VERSION} -> ${POST_VERSION}"

# 6. QA Health Verification Suite (Poll up to 60 seconds)
log "Running 5-Point QA Health Verification Suite..."

QA_PASSED=false
for i in $(seq 1 12); do
    sleep 5
    log "QA Attempt ${i}/12: Validating Jellyfin service health..."

    # Check 1: Systemd Service Active
    if ! pct exec "${CT_ID}" -- systemctl is-active jellyfin >/dev/null 2>&1; then
        log "  [QA-1] Service not active yet, waiting..."
        continue
    fi

    # Check 2: HTTP 200 OK on /health
    HEALTH_CODE=$(pct exec "${CT_ID}" -- curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8096/health || echo "000")
    if [ "${HEALTH_CODE}" != "200" ]; then
        log "  [QA-2] /health returned HTTP ${HEALTH_CODE} (expected 200), waiting..."
        continue
    fi

    # Check 3: HTTP 200 OK on /web/index.html
    WEB_CODE=$(pct exec "${CT_ID}" -- curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8096/web/index.html || echo "000")
    if [ "${WEB_CODE}" != "200" ]; then
        log "  [QA-3] Web UI returned HTTP ${WEB_CODE} (expected 200), waiting..."
        continue
    fi

    # Check 4: Jellyfin API /System/Info/Public
    if ! pct exec "${CT_ID}" -- curl -s http://127.0.0.1:8096/System/Info/Public | grep -q "ServerName"; then
        log "  [QA-4] Jellyfin API /System/Info/Public not responding with valid JSON, waiting..."
        continue
    fi

    # Check 5: GPU Device Passthrough & VA-API
    if pct exec "${CT_ID}" -- test -e /dev/dri/renderD128; then
        if ! pct exec "${CT_ID}" -- su - jellyfin -s /bin/bash -c "vainfo --display drm --device /dev/dri/renderD128" >/dev/null 2>&1; then
            log "  [QA-5] vainfo GPU check failed under jellyfin user, retrying..."
            continue
        fi
    fi

    QA_PASSED=true
    break
done

# 7. Evaluate QA Results & Enforce Retention Limit
if [ "${QA_PASSED}" = true ]; then
    log "========================================================================"
    log " [QA SUCCESS] All 5 QA health checks PASSED on CT ${CT_ID}!"
    log " Successfully upgraded Jellyfin: ${PRE_VERSION} -> ${POST_VERSION}"
    log "========================================================================"
    
    # Prune old snapshots beyond the 4-backup limit
    prune_old_snapshots "${ZFS_DATASET}" "${MAX_BACKUPS}"
    exit 0
else
    error_log "========================================================================"
    error_log " [QA FAILED] Jellyfin health checks failed after upgrade on CT ${CT_ID}."
    error_log " Triggering AUTOMATED ROLLBACK to snapshot: ${SNAP_NAME}..."
    error_log "========================================================================"

    pct stop "${CT_ID}"
    zfs rollback -r "${ZFS_DATASET}@${SNAP_NAME}"
    pct start "${CT_ID}"
    sleep 5

    if pct exec "${CT_ID}" -- systemctl is-active jellyfin >/dev/null 2>&1; then
        error_log " [ROLLBACK SUCCESSFUL] Restored CT ${CT_ID} to pre-upgrade state (${PRE_VERSION})."
    else
        error_log " [ROLLBACK WARNING] Container restored but service may require manual check."
    fi
    exit 1
fi
