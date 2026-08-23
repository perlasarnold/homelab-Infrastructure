# Homelab Configuration Pull Scripts

This directory contains scripts to automatically pull configurations from Proxmox and Unraid servers to keep documentation and Terraform configurations in sync. Synology DSM exports live in a small Python helper (run on the LAN).

## Scripts

### dapitan-copy-pnas-movies.sh (Bash)

Safely copies `\\pnas\Seagate\Share\Movies\` to Dapitan's
`bulk18/media-data` movie library. It mounts the SMB source read-only,
validates the ZFS destination, defaults to a dry-run, never deletes
destination files, and requires `--execute` for the real transfer. See
[`Dapitan-PNAS-Movies-Copy-2026-07-23.md`](../06-Guides/Dapitan-PNAS-Movies-Copy-2026-07-23.md).

### synology-dsm-export/ (Python)

Exports DSM settings via the Synology Web API (static endpoints + optional full catalog probe). Prefer **`python dump_dsm_settings.py --browser`** (Playwright Chromium — you log in; 2FA OK). See [`synology-dsm-export/README.md`](synology-dsm-export/README.md) and `Run-DsmExport.ps1`.

### pull-proxmox-config.ps1
Pulls current LXC container and VM configurations from Proxmox server and generates Terraform files.

### pull-unraid-config.ps1
Pulls current Docker container configurations from Unraid server and generates Terraform files.

### update-docs.ps1
Updates the overview documentation files with current status information from both servers.

## Prerequisites

- PowerShell 5.1+
- For Proxmox: API token with appropriate permissions
- For Unraid: SSH access or Docker TCP API enabled
- For Synology: Python 3.10+ and `pip install -r synology-dsm-export/requirements.txt`
- Required modules: None for PowerShell scripts (uses built-in PowerShell capabilities)

## Usage

```powershell
# Pull Proxmox configurations
.\pull-proxmox-config.ps1

# Pull Unraid configurations
.\pull-unraid-config.ps1

# Update documentation
.\update-docs.ps1

# Run all
.\pull-all-configs.ps1
```
