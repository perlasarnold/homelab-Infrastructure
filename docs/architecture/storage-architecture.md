# 🗄️ Synology Overview

> **Hostname:** `pnas.local` | **Web UI:** https://pnas.local:5001  
> **Model:** DS920+ | **DSM Version:** 7.x | **IP:** 192.168.1.x (DHCP)  
> **Last Updated:** 2026-04-19 | **Maintainer:** Perlas  
> **Status:** Production | **Reproducibility Score:** 6/10 (See Scalability Section)

---

## What is Synology DSM?

Synology DiskStation Manager (DSM) is a **NAS (Network Attached Storage) operating system** that provides file sharing, data protection, multimedia services, and virtualized applications through an intuitive web interface.

- **Primary use:** File storage, backups, and media serving
- **Secondary use:** Surveillance, Docker containers, and cloud sync

---

## Host Hardware

| Component | Details |
|-----------|---------|
| Model | DS920+ |
| CPU | Intel Celeron J4125 (4-core, 2.0-2.7 GHz) |
| RAM | 4 GB DDR4 (expandable to 8 GB) |
| Drive Bays | 4x 3.5" SATA HDD/SSD |
| M.2 Slots | 2x NVMe SSD for caching |
| LAN Ports | 2x 1GbE RJ-45 (link aggregation capable) |
| USB Ports | 2x USB 3.0 |

---

## Storage Configuration

| Bay | Drive | Size | Role | File System |
|-----|-------|------|------|-------------|
| 1 | (populated) | - | Storage Pool 1 | Btrfs |
| 2 | (populated) | - | Storage Pool 1 | Btrfs |
| 3 | (optional) | - | Expansion | - |
| 4 | (optional) | - | Expansion | - |

**Storage Pool 1:** RAID 1/SHR (depending on configuration) with Btrfs
- Snapshots enabled
- Checksum integrity checking
- Compression enabled

---

## Shared Folders

| Folder | Purpose | Access | Notes |
|--------|---------|--------|-------|
| homes | User home directories | Per-user | Private user storage |
| photo | Photo library | Multi-user | Used by Photo Station / Synology Photos |
| music | Music library | Multi-user | Indexed for Audio Station |
| video | Video content | Multi-user | Media server source |
| backup | System backups | Admin | Hyper Backup destination |
| docker | Docker volumes | Admin | Container persistent data |
| documents | General documents | Multi-user | Shared work files |

---

## Installed Packages

| Package | Purpose | Status |
|---------|---------|--------|
| Synology Photos | Photo management & sharing | Running |
| Hyper Backup | Backup to local/remote/cloud | Configured |
| Snapshot Replication | Btrfs snapshot management | Running |
| Docker | Container runtime | Running |
| Cloud Sync | Sync with cloud providers | Configured |
| Audio Station | Music server | Running |
| Video Station | Media server (optional) | Depends on preference |
| Synology Drive | File sync (like Dropbox) | Running |
| Universal Search | Content indexing | Running |
| Antivirus Essential | Malware scanning | Scheduled |

---

## Network Configuration

| Setting | Value |
|---------|-------|
| IP Address | 192.168.1.x (DHCP reservation recommended) |
| Subnet | 255.255.255.0 |
| Gateway | VLAN 1 [Gateway] |
| DNS | VLAN 1 (Mgmt) (Pi-hole) |
| Hostname | pnas.local |
| Link Aggregation | Optional (if using both LAN ports) |

**QuickConnect / DDNS:** Optional — see Control Panel → External Access

---

## Backup & Data Protection

| Feature | Configuration |
|---------|---------------|
| Hyper Backup | Scheduled backups to external USB/cloud |
| Snapshots | Automated daily snapshots (retention: 30 days) |
| Recycle Bin | Enabled on shared folders |
| BTRFS Scrubbing | Monthly scheduled |

---

## Docker Containers (if enabled)

See `Container Manager` in DSM for currently running containers.

Common containers:
| Container | Purpose | Ports |
|-----------|---------|-------|
| (to be populated) | | |

---

## Automated Settings Export

DSM settings are managed in the browser. To keep **version-controlled documentation**, use the local Python exporter:

**Tool location:** [`scripts/synology-dsm-export/`](../scripts/synology-dsm-export/README.md)

**Recommended (2FA-friendly):**
```powershell
cd scripts\synology-dsm-export
pip install -r requirements-browser.txt
playwright install chromium
python dump_dsm_settings.py --browser
```

**Outputs (gitignored by default):**
- `out/dsm-full-<timestamp>.md` — human-readable summary
- `out/dsm-full-<timestamp>.json` — full API export

> **Note:** For **restore-capable** backups, use DSM **Control Panel → Update & Restore → Configuration Backup**.

---

## Security Considerations

| Setting | Recommendation |
|---------|----------------|
| Admin user | Disabled or restricted; use non-admin daily account |
| 2FA | Enabled for all admin users |
| HTTPS | Forced redirect to HTTPS on port 5001 |
| Firewall | Enabled with default rules |
| Auto-block | Enabled for failed login attempts |
| Security Advisor | Run monthly and address findings |
| Automatic Updates | Enabled for critical DSM updates |

---

## Related Pages

- [[03-Unraid/Unraid Overview]] — Primary NAS with Docker
- [[04-Network/Network Overview]] — full network map
- [[05-Services/Services Index]] — service URLs

---

## Scalability & Reproducibility

### Current State
Synology DSM configuration is primarily **manual** via the web UI. The `synology-dsm-export` script provides **documentation snapshots** but not true infrastructure-as-code. Current reproducibility: **6/10**.

### Areas for Improvement

#### 1. API-Based Configuration
- **Current**: Manual GUI configuration
- **Target**: Script initial setup via Synology Web API
- **Challenge**: DSM lacks native Terraform/ARM support
- **Alternative**: Document exact UI steps in runbooks

#### 2. Configuration Templating
- **Current**: One-off exports to JSON
- **Target**: Version-controlled configuration templates
- **Benefit**: Track changes over time

#### 3. Automated Documentation
- **Current**: Manual export via browser script
- **Target**: Scheduled exports via cron/systemd timer
- **Implementation**: Adapt `dump_dsm_settings.py` for headless/API auth

#### 4. Docker Container Management
- **Current**: Container Manager GUI
- **Target**: Docker Compose files in git + Portainer
- **Benefit**: Reproducible container deployments

#### 5. Hybrid NAS Strategy (Proposed)
- **Unraid (Mercado):** Primary Docker host, large storage, media serving
- **Synology (PNAS):** Critical data redundancy, snapshots, offsite backup source
- **Sync:** Use `rclone` or Synology Cloud Sync to replicate key datasets

### Reproducibility Checklist for New Devices
When setting up a new Synology NAS:

1. [ ] Install DSM (latest stable version)
2. [ ] Create admin account, disable default admin
3. [ ] Enable 2FA for all admin accounts
4. [ ] Configure network settings (static IP or DHCP reservation)
5. [ ] Create storage pool and shared folders
6. [ ] Install required packages (Photos, Hyper Backup, Drive, Docker)
7. [ ] Configure Hyper Backup schedule
8. [ ] Set up snapshot retention policies
9. [ ] Configure Cloud Sync to Unraid (if hybrid setup desired)
10. [ ] Run `dump_dsm_settings.py --browser` to capture baseline
11. [ ] Update this documentation with actual values

### Next Steps
1. [ ] Fill in actual hardware details (drive models, sizes)
2. [ ] Document current shared folder structure with sizes
3. [ ] List currently installed packages with versions
4. [ ] Configure automated settings export (monthly)
5. [ ] Evaluate Docker migration strategy to/from Unraid
