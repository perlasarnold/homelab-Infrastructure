#!/usr/bin/env bash
set -Eeuo pipefail

# Copy the contents of \\pnas\Seagate\Share\TV Shows to Dapitan's
# bulk18/media-data library (/mnt/bindmounts/media-data/library/tv).
# The SMB source is always mounted read-only.
#
# Safety defaults:
# - dry-run unless --execute is supplied
# - no destination deletion
# - no source ownership/permission propagation
# - one active copy process at a time

readonly SOURCE_SERVER="${SOURCE_SERVER:-VLAN 1 [Management]}"
readonly SOURCE_SHARE="${SOURCE_SHARE:-Seagate}"
readonly SOURCE_SUBDIR="${SOURCE_SUBDIR:-Share/TV Shows}"
readonly SOURCE_MOUNT="${SOURCE_MOUNT:-/mnt/source-pnas-seagate-tv}"
readonly DESTINATION="${DESTINATION:-/mnt/bindmounts/media-data/library/tv}"
readonly EXPECTED_DEST_SOURCE="${EXPECTED_DEST_SOURCE:-bulk18/media-data}"
readonly SMB_CREDENTIAL_FILE="${SMB_CREDENTIAL_FILE:-/etc/dapitan-copy/pnas-seagate.credentials}"
readonly LOG_DIR="${LOG_DIR:-/var/log/dapitan-pnas-tvshows-copy}"
readonly LOCK_FILE="${LOCK_FILE:-/run/lock/dapitan-pnas-tvshows-copy.lock}"

mode="dry-run"
bwlimit_kib="${BWLIMIT_KIB:-81920}"
mounted_by_script=0
log_file=""

usage() {
  cat <<'EOF'
Usage:
  dapitan-copy-pnas-tvshows.sh --check
  dapitan-copy-pnas-tvshows.sh [--dry-run] [--bwlimit-kib N]
  dapitan-copy-pnas-tvshows.sh --execute [--bwlimit-kib N]

Modes:
  --check          Validate credentials, source, destination, mounts, and ZFS.
  --dry-run        Show what rsync would copy. This is the default.
  --execute        Perform the one-way copy. Destination files are not deleted.

Options:
  --bwlimit-kib N  Limit rsync throughput in KiB/s. Default: 81920 (80 MiB/s).
  -h, --help       Show this help text.

Environment overrides:
  SOURCE_SERVER, SOURCE_SHARE, SOURCE_SUBDIR, SOURCE_MOUNT, DESTINATION,
  EXPECTED_DEST_SOURCE, SMB_CREDENTIAL_FILE, LOG_DIR, LOCK_FILE,
  BWLIMIT_KIB
EOF
}

log() {
  local message
  message="$(date --iso-8601=seconds) $*"
  printf '%s\n' "$message"
  if [[ -n "$log_file" ]]; then
    printf '%s\n' "$message" >>"$log_file"
  fi
}

fail() {
  log "ERROR: $*"
  exit 1
}

cleanup() {
  local exit_code=$?

  if (( mounted_by_script == 1 )) && mountpoint -q "$SOURCE_MOUNT"; then
    if ! umount -- "$SOURCE_MOUNT"; then
      log "WARNING: could not unmount $SOURCE_MOUNT; inspect it manually."
    fi
  fi

  exit "$exit_code"
}

trap cleanup EXIT INT TERM

while (($# > 0)); do
  case "$1" in
    --check)
      mode="check"
      shift
      ;;
    --dry-run)
      mode="dry-run"
      shift
      ;;
    --execute)
      mode="execute"
      shift
      ;;
    --bwlimit-kib)
      (($# >= 2)) || fail "--bwlimit-kib requires a value."
      bwlimit_kib="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

[[ "$EUID" -eq 0 ]] || fail "run this script as root on Dapitan."
[[ "$bwlimit_kib" =~ ^[1-9][0-9]*$ ]] ||
  fail "bandwidth limit must be a positive integer in KiB/s."

for command_name in flock findmnt ionice mount.cifs mountpoint nice rsync zfs; do
  command -v "$command_name" >/dev/null ||
    fail "required command is missing: $command_name"
done

install -d -m 0700 -- "$LOG_DIR"
log_file="$LOG_DIR/$(date +%Y%m%d-%H%M%S)-${mode}.log"
touch -- "$log_file"
chmod 0600 -- "$log_file"

exec 9>"$LOCK_FILE"
flock -n 9 || fail "another Dapitan TV-shows-copy process is already active."

[[ -r "$SMB_CREDENTIAL_FILE" ]] ||
  fail "saved Seagate SMB credential file is not readable: $SMB_CREDENTIAL_FILE"
[[ "$(stat -c '%U' "$SMB_CREDENTIAL_FILE")" == "root" ]] ||
  fail "SMB credential file must be owned by root: $SMB_CREDENTIAL_FILE"
credential_mode="$(stat -c '%a' "$SMB_CREDENTIAL_FILE")"
[[ "$credential_mode" == "600" || "$credential_mode" == "400" ]] ||
  fail "SMB credential file mode must be 0600 or 0400: $SMB_CREDENTIAL_FILE"

expected_unc="//${SOURCE_SERVER}/${SOURCE_SHARE}"
if mountpoint -q "$SOURCE_MOUNT"; then
  mounted_source="$(findmnt -rn -o SOURCE -M "$SOURCE_MOUNT")"
  [[ "${mounted_source,,}" == "${expected_unc,,}" ]] ||
    fail "$SOURCE_MOUNT is already mounted from unexpected source: $mounted_source"
  log "Using existing read-only mount: $mounted_source"
else
  mkdir -p -- "$SOURCE_MOUNT"
  log "Mounting $expected_unc read-only at $SOURCE_MOUNT"
  mount.cifs "$expected_unc" "$SOURCE_MOUNT" \
    -o "credentials=${SMB_CREDENTIAL_FILE},ro,vers=3.1.1,iocharset=utf8,noserverino,uid=0,gid=0,file_mode=0444,dir_mode=0555"
  mounted_by_script=1
fi

mount_options="$(findmnt -rn -o OPTIONS -M "$SOURCE_MOUNT")"
[[ ",$mount_options," == *,ro,* ]] ||
  fail "source mount is not read-only: $mount_options"

source_path="${SOURCE_MOUNT}/${SOURCE_SUBDIR}"
[[ -d "$source_path" ]] ||
  fail "source directory does not exist: $source_path"

if [[ -z "$(find "$source_path" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
  fail "source directory is empty; refusing to continue."
fi

mkdir -p -- "$DESTINATION"

destination_source="$(findmnt -rn -o SOURCE -T "$DESTINATION")"
destination_fstype="$(findmnt -rn -o FSTYPE -T "$DESTINATION")"
[[ "$destination_source" == "$EXPECTED_DEST_SOURCE" ]] ||
  fail "destination is on $destination_source, expected $EXPECTED_DEST_SOURCE."
[[ "$destination_fstype" == "zfs" ]] ||
  fail "destination filesystem is $destination_fstype, expected zfs."
[[ "$(zfs get -H -o value readonly "$EXPECTED_DEST_SOURCE")" == "off" ]] ||
  fail "destination ZFS dataset is read-only."

log "Validated source: ${expected_unc}/${SOURCE_SUBDIR}"
log "Validated destination: $DESTINATION on $destination_source"
log "Available destination bytes: $(df -PB1 "$DESTINATION" | awk 'NR == 2 {print $4}')"

if [[ "$mode" == "check" ]]; then
  log "Check completed successfully; no files were copied."
  exit 0
fi

rsync_options=(
  --recursive
  --links
  --safe-links
  --times
  --hard-links
  --human-readable
  --itemize-changes
  --info=progress2,stats2
  --partial
  --partial-dir=.rsync-partial
  --no-owner
  --no-group
  --no-perms
  --chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r
  --bwlimit="$bwlimit_kib"
  --exclude=/#recycle/
  --exclude=/#snapshot/
  --exclude=/@eaDir/
  --exclude=/.DS_Store
)

if [[ "$mode" == "dry-run" ]]; then
  rsync_options+=(--dry-run)
  log "Starting rsync dry-run; no files will be copied."
else
  log "Starting rsync copy with ${bwlimit_kib} KiB/s bandwidth limit."
fi

if ionice -c 2 -n 7 nice -n 10 \
  rsync "${rsync_options[@]}" -- "${source_path}/" "${DESTINATION}/" \
  2>&1 | tee -a "$log_file"; then
  log "Rsync ${mode} completed successfully."

  if [[ "$mode" == "execute" ]]; then
    log "Enforcing read/execute permissions on library dataset..."
    chmod -R a+rX "${DESTINATION}" || true

    log "Triggering post-sync library refresh for Plex (CT 509) and Jellyfin (CT 510)..."
    pct exec 509 -- su - plex -s /bin/bash -c "export LD_LIBRARY_PATH=/usr/lib/plexmediaserver/lib; /usr/lib/plexmediaserver/Plex\ Media\ Scanner --scan --section 2" >/dev/null 2>&1 || true
    pct exec 510 -- curl -s -X POST "http://127.0.0.1:8096/Library/Refresh?api_key=<YOUR_JELLYFIN_API_KEY>" >/dev/null 2>&1 || true
    log "Post-sync library refresh commands dispatched."
  fi
else
  rsync_exit="${PIPESTATUS[0]}"
  log "ERROR: rsync ${mode} failed with exit code ${rsync_exit}."
  exit "$rsync_exit"
fi
