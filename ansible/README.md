# Proxmox VE & LXC/VM Sequential Update System
Core Homelab automated sequential update solution using Ansible

## Overview
A production-grade, cluster-aware update system for Proxmox VE (PVE) nodes and their virtualized guest workloads (LXCs and VMs).

This system executes **sequentially (`serial: 1`)** across your cluster nodes to prevent downtime, automatically creating pre-update snapshots for containers and rolling back if any container update or health check fails.

---

## Key Features
- 🔄 **Sequential Execution (`serial: 1`)**: Updates host nodes strictly one at a time.
- ⏰ **3rd Sunday Schedule**: Automated scheduling for every **3rd Sunday of the month at 2:00 AM Pacific Time**.
- 🛡️ **Cluster Quorum Verification**: Validates `pvecm status` before starting node updates and after node reboots to avoid split-brain issues.
- 📸 **Pre-Update Guest Snapshots**: Takes automated snapshots (`pct snapshot` / `qm snapshot`) before updating guests.
- ⏪ **Automated Guest Rollback**: Automatically rolls back container state if update commands or health checks fail.
- ⛔ **Configurable Exclusion Lists**: Prevents updating critical services (e.g., DNS, Firewalls, Storage).
- 🏷️ **Repository Management**: Handles enterprise vs. no-subscription repository switching automatically.
- 🪵 **Centralized Audit Logging**: Logs all actions to `/var/log/proxmox-updates.log` and `/var/log/proxmox-cron-updates.log`.

---

## File Structure

```text
homelab/ansible/
├── ansible.cfg                    # Default Ansible connection and callback settings
├── inventory/
│   └── proxmox.ini                # Proxmox nodes inventory list
├── vars/
│   └── proxmox_update.yml         # Centralized configuration & exclusion rules
├── roles/
│   └── proxmox_update/
│       └── tasks/
│           ├── main.yml           # Workflow controller (Cluster check -> Host -> LXC -> VM)
│           ├── update_host.yml    # PVE host OS update & safe reboot handling
│           ├── process_lxc.yml    # LXC snapshot, update (pct exec), health check, rollback
│           └── process_vm.yml     # VM snapshot, update (qm guest exec), health check, rollback
├── proxmox_update.yml             # Main playbook entry point
├── schedule_proxmox_updates.yml   # Ansible playbook to program 3rd Sunday at 2 AM Pacific schedule
├── run_update.sh                  # Bash trigger script for Linux/Mac/WSL
├── run_update.ps1                 # PowerShell trigger script for Windows
└── README.md                      # Documentation
```

---

## Quick Start

### 1. Trigger via Bash / Linux / Proxmox Shell
```bash
cd /root/homelab/ansible

# Standard update run (Host OS + LXC + VM)
./run_update.sh

# Dry-run mode (check without making changes)
./run_update.sh --check

# Auto-reboot hosts if kernel update requires reboot
./run_update.sh --auto-reboot

# Update only LXC containers
./run_update.sh --lxc-only

# Update only host hypervisors
./run_update.sh --host-only
```

### 2. Trigger from Windows via PowerShell
```powershell
# From Windows terminal:
.\run_update.ps1 -ProxmoxHost "192.168.1.25"

# With automatic host reboot:
.\run_update.ps1 -ProxmoxHost "192.168.1.25" -AutoReboot
```

---

## Scheduling (3rd Sunday of the Month at 2:00 AM Pacific)

To deploy the schedule onto your Proxmox host(s):

```bash
cd /root/homelab/ansible
ansible-playbook schedule_proxmox_updates.yml
```

This installs both a **Crontab entry** and a **Systemd Timer (`proxmox-update.timer`)**:
- **Cron Pattern**: `0 2 15-21 * *` combined with `test $(date +%u) -eq 7` (guarantees execution only on the 3rd Sunday of the month).
- **Systemd Timer Calendar**: `OnCalendar=Sun *-*-15..21 02:00:00 America/Los_Angeles` with `Persistent=true` so missed runs (if host was off) run on boot.
- **Log Files**: Automated scheduled logs write to `/var/log/proxmox-cron-updates.log`.

---

## Configuration (`vars/proxmox_update.yml`)

Configure exclusions and behavior in `vars/proxmox_update.yml`:

```yaml
# Global settings
proxmox_update_log_path: "/var/log/proxmox-updates.log"

# Host settings
proxmox_update_host: true
proxmox_host_repo_type: "no-subscription" # "no-subscription", "enterprise", or "none"
proxmox_auto_reboot: false                 # Automatically reboot node if kernel requires reboot

# Exclusions - these IDs will NEVER be updated automatically
proxmox_exclude_lxc:
  - 100  # Pi-hole Primary
  - 101  # Pi-hole Secondary
  - 102  # WireGuard VPN
  - 103  # Cloudflare Tunnel

proxmox_exclude_vms:
  - 200  # OPNsense Firewall
  - 201  # TrueNAS Core
  - 204  # Immich-UbuntuLTS
```
