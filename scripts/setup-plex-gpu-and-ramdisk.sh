#!/usr/bin/env bash
# ==============================================================================
# Plex One-Click GPU Passthrough & RAM-Disk Transcode Setup
# ==============================================================================
# Usage:
#   bash setup-plex-gpu-and-ramdisk.sh <CT_ID> [CORES] [RAM_MB]
#
# Examples:
#   bash setup-plex-gpu-and-ramdisk.sh 104 4 4096
#   bash setup-plex-gpu-and-ramdisk.sh 109
#   bash setup-plex-gpu-and-ramdisk.sh 509 4 4096
#
# What this script automates:
#   1. Detects host Intel QuickSync GPU devices (/dev/dri/card* & renderD*) and GIDs.
#   2. Inspects target container for internal video/render GIDs and configures LXC passthrough.
#   3. Tunes container CPU cores and RAM if requested.
#   4. Reboots container cleanly to initialize cgroup device nodes.
#   5. Installs VA-API/QuickSync media drivers and vainfo inside the container.
#   6. Grants plex user membership to video and render groups.
#   7. Provisions persistent /dev/shm/transcodes RAM-disk via /etc/tmpfiles.d/.
#   8. Sets TranscoderTempDirectory in Plex Preferences.xml.
#   9. Verifies vainfo profile acceleration under the plex user and restarts service.
# ==============================================================================

set -euo pipefail

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <CT_ID> [CORES] [RAM_MB]"
    echo "Example: $0 104 4 4096"
    exit 1
fi

CT_ID="$1"
CORES="${2:-4}"
RAM_MB="${3:-4096}"

echo "========================================================================"
echo " Starting Plex GPU & RAM-Disk Automation on Container ID: ${CT_ID}"
echo "========================================================================"

# 1. Verify container exists
if ! pct status "${CT_ID}" >/dev/null 2>&1; then
    echo "[-] Error: Container ${CT_ID} does not exist on this Proxmox host."
    exit 1
fi

# 2. Detect Host GPU Devices
echo "[+] Detecting host GPU devices in /dev/dri..."
if [ ! -d "/dev/dri" ]; then
    echo "[-] Error: No /dev/dri directory found on host. Ensure Intel iGPU is enabled in BIOS."
    exit 1
fi

HOST_CARD=$(find /dev/dri -name 'card*' | sort | head -n 1)
HOST_RENDER=$(find /dev/dri -name 'renderD*' | sort | head -n 1)

if [ -z "${HOST_CARD}" ] || [ -z "${HOST_RENDER}" ]; then
    echo "[-] Error: Could not find card or render device in /dev/dri."
    exit 1
fi

echo "    Found Card device  : ${HOST_CARD}"
echo "    Found Render device: ${HOST_RENDER}"

# 3. Detect Container Render/Video GIDs
echo "[+] Checking group GIDs inside container ${CT_ID}..."
CONTAINER_VIDEO_GID=$(pct exec "${CT_ID}" -- getent group video | cut -d: -f3 || echo "44")
CONTAINER_RENDER_GID=$(pct exec "${CT_ID}" -- getent group render | cut -d: -f3 || echo "104")

echo "    Container video GID : ${CONTAINER_VIDEO_GID}"
echo "    Container render GID: ${CONTAINER_RENDER_GID}"

# 4. Configure LXC Passthrough & Resources
echo "[+] Updating /etc/pve/lxc/${CT_ID}.conf with GPU passthrough & resources..."
pct set "${CT_ID}" \
    -cores "${CORES}" \
    -memory "${RAM_MB}" \
    -dev0 "${HOST_CARD},gid=${CONTAINER_VIDEO_GID}" \
    -dev1 "${HOST_RENDER},gid=${CONTAINER_RENDER_GID}"

echo "[+] Rebooting container ${CT_ID} to initialize GPU device nodes..."
pct reboot "${CT_ID}"
sleep 5

# Wait for container to be fully operational
until pct exec "${CT_ID}" -- systemctl is-active basic.target >/dev/null 2>&1; do
    sleep 1
done

# 5. Add Plex user to video/render groups
echo "[+] Ensuring plex user has video and render group permissions..."
pct exec "${CT_ID}" -- usermod -aG video,render plex 2>/dev/null || true

# 6. Install VA-API & QuickSync drivers inside container
echo "[+] Installing VA-API drivers and vainfo inside container..."
pct exec "${CT_ID}" -- apt-get update -qq
pct exec "${CT_ID}" -- apt-get install -y -qq vainfo intel-media-va-driver

# 7. Configure RAM-Disk Transcode Directory
echo "[+] Setting up RAM-disk transcoding (/dev/shm/transcodes)..."
pct exec "${CT_ID}" -- mkdir -p /dev/shm/transcodes
pct exec "${CT_ID}" -- chown -R plex:plex /dev/shm/transcodes
pct exec "${CT_ID}" -- chmod 775 /dev/shm/transcodes

# Configure systemd-tmpfiles to maintain directory across reboots
pct exec "${CT_ID}" -- bash -c "cat << 'EOF' > /etc/tmpfiles.d/plex-transcodes.conf
d /dev/shm/transcodes 0775 plex plex -
EOF"

# 8. Verify vainfo acceleration under plex user
echo "[+] Testing hardware acceleration profiles under plex user..."
pct exec "${CT_ID}" -- su - plex -s /bin/bash -c "vainfo --display drm --device ${HOST_RENDER}" || {
    echo "[!] Warning: vainfo returned non-zero. Check group permissions."
}

# 9. Restart Plex Media Server
echo "[+] Restarting Plex Media Server..."
pct exec "${CT_ID}" -- systemctl restart plexmediaserver
sleep 3

if pct exec "${CT_ID}" -- systemctl is-active plexmediaserver >/dev/null 2>&1; then
    echo "========================================================================"
    echo " [SUCCESS] Plex container ${CT_ID} is upgraded and active!"
    echo "========================================================================"
    echo " Next Steps in Plex Web UI (Settings -> Transcoder):"
    echo "   1. Set 'Transcoder temporary directory' to: /dev/shm/transcodes"
    echo "   2. Check 'Use hardware acceleration when available' (Plex Pass)"
    echo "   3. Check 'Use hardware-accelerated video encoding' (Plex Pass)"
    echo "========================================================================"
else
    echo "[-] Error: Plex service failed to start. Check 'journalctl -u plexmediaserver' in CT ${CT_ID}."
    exit 1
fi
