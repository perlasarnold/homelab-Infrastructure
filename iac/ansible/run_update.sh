#!/usr/bin/env bash
# ==============================================================================
# Proxmox VE & LXC/VM Sequential Update Launcher Script
# ==============================================================================
# Usage:
#   ./run_update.sh                      # Standard run (Host + LXC + VM)
#   ./run_update.sh --check              # Dry-run check mode
#   ./run_update.sh --auto-reboot        # Auto reboot hosts if kernel updated
#   ./run_update.sh --lxc-only           # Update only LXC containers
#   ./run_update.sh --host-only          # Update only Proxmox host OS
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

EXTRA_VARS=""
TAGS_ARG=""
CHECK_MODE=""

for arg in "$@"; do
  case $arg in
    --check|--dry-run)
      CHECK_MODE="--check"
      shift
      ;;
    --auto-reboot)
      EXTRA_VARS="-e proxmox_auto_reboot=true"
      shift
      ;;
    --host-only)
      TAGS_ARG="--tags host"
      shift
      ;;
    --lxc-only)
      TAGS_ARG="--tags lxc"
      shift
      ;;
    --vm-only)
      TAGS_ARG="--tags vm"
      shift
      ;;
  esac
done

echo "============================================================"
echo " Starting Proxmox Sequential Update Playbook"
echo " Time: $(date)"
echo " Playbook Directory: $SCRIPT_DIR"
echo "============================================================"

ansible-playbook -i inventory/proxmox.ini proxmox_update.yml $CHECK_MODE $TAGS_ARG $EXTRA_VARS

EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
  echo "============================================================"
  echo " SUCCESS: All Proxmox nodes and workloads updated."
  echo " Log location on PVE node: /var/log/proxmox-updates.log"
  echo "============================================================"

  # Execute Cebu dedicated service updates (fail2ban, Tailscale, Grafana, Uptime Kuma)
  if [ -z "$TAGS_ARG" ] || [ "$TAGS_ARG" = "--tags lxc" ]; then
    echo "============================================================"
    echo " Starting Cebu Managed Services Update (cebu_services.yml)"
    echo "============================================================"
    ansible-playbook -i inventory/proxmox.ini cebu_services.yml $CHECK_MODE
    CEBU_SERVICES_EXIT=$?
    if [ $CEBU_SERVICES_EXIT -ne 0 ]; then
      echo " WARNING: Cebu services update encountered errors (exit code: $CEBU_SERVICES_EXIT)"
    else
      echo " SUCCESS: Cebu services updated and verified."
    fi
  fi
else
  echo "============================================================"
  echo " ERROR: Update failed on step with exit code $EXIT_CODE."
  echo " Check log at /var/log/proxmox-updates.log on target node."
  echo "============================================================"
fi

exit $EXIT_CODE

