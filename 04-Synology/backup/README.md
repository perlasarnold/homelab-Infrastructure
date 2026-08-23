# Synology DSM Configuration Backup

> **Generated:** April 20, 2026  
> **Source:** Synology DS920+ (S/N: 2220TERRSGKFA)  
> **DSM Version:** 7.2.2-72806 Update 5  
> **Export Tool:** synology-dsm-export script

---

## How This Backup Works

This folder contains a **documentation-level export** of your Synology DSM configuration — not a full system image, but a machine-readable record of settings that can guide reconfiguration or detect drift.

---

## Files in This Backup

| File | Purpose | Format |
|------|---------|--------|
| `Current-Config-Extract.json` | Core configuration snapshot (this run) | JSON |
| `dsm-full-20260420-033801Z.json` | Full API export from this session | JSON |
| `dsm-full-20260420-033801Z.md` | Human-readable truncated summary | Markdown |
| `README.md` | This file — how to use and restore | Markdown |

---

## What This Backup Captures

✅ **System Information**
- Model, serial number, CPU, RAM
- DSM version and uptime
- Temperature and health status

✅ **Network Settings**
- IP configuration, DNS, gateway
- Server name, interface settings
- DHCP and hostname configuration

✅ **Storage Configuration**
- Storage pools and volumes
- Disk information and health
- Shared folders and encryption status

✅ **Installed Packages**
- Package names and versions
- Running/stopped status
- Repository sources

✅ **Security Settings**
- AutoBlock (failed login attempts)
- Password policies
- SSH/Terminal access settings

✅ **User Management**
- Usernames and base privileges
- Group memberships

❌ **What This Backup Does NOT Capture**
- Actual data files in shared folders
- Encryption keys or passwords
- Docker container data
- VM images
- Hyper Backup tasks
- System certificates

---

## For Full System Backup

Configuration exports are **documentation**, not restore-ready backups. For bare-metal recovery, also maintain:

### Option A: DSM Built-in Configuration Backup
```
DSM Control Panel → Update & Restore → Configuration Backup
→ Save to external USB or another NAS
```

### Option B: Hyper Backup
```
DSM Package Center → Install Hyper Backup
→ Create backup task to USB, cloud, or another NAS
→ Include: System configuration + selected shared folders
```

### Option C: Automated Daily Exports
1. Schedule this script via DSM Task Scheduler
2. Export to a version-controlled location
3. Commit changes to track configuration drift

---

## Using This Backup

### 1. Reference During Reconfiguration
After a DSM reinstall, open `Current-Config-Extract.json` and manually recreate:
- Network settings (static IP, DNS, server name)
- Shared folders (names, permissions, encryption)
- Installed packages
- User accounts

### 2. Configuration Drift Detection
Compare exports over time:
```bash
# See what changed between two exports
diff <(jq -S . config-2024-01.json) <(jq -S . config-2024-06.json)
```

### 3. Documentation for Troubleshooting
When issues arise, check the export for:
- Package versions (rollback if needed)
- Network changes
- Security settings

---

## Restoring From This Backup

### Step-by-Step Reconfiguration

1. **Fresh DSM Install**
   - Complete initial DSM setup
   - Do NOT restore from .dss file (this is manual reference)

2. **Network Settings** (`network` section)
   - Control Panel → Network → General
   - Server name: `PNAS`
   - Default gateway: `VLAN 1 [Gateway]`
   - DNS: `VLAN 1 [Gateway]` (update to Pi-hole: `VLAN 1 (Mgmt)`)

3. **Storage** (`storage` section)
   - Storage Manager → Create storage pool (match RAID type)
   - Create volumes → Create shared folders (match names from export)

4. **Shared Folders** (`shares` section)
   - Control Panel → Shared Folder → Create
   - Recreate: `ActiveBackupforBusiness`, `Documents`, `Media`, `photo`, etc.
   - Re-apply permissions

5. **Packages** (`packages` section)
   - Package Center → Install each package from export
   - Match versions where critical

6. **Users** (`users` section)
   - Control Panel → User & Group → Create users

7. **Security** (`security` section)
   - Control Panel → Security → Auto Block (enable)
   - Control Panel → Terminal → Enable SSH if needed

---

## Automating Future Backups

### From Your PC (Windows)
```powershell
cd scripts\synology-dsm-export
python dump_dsm_settings.py --browser
```

### From Synology (Task Scheduler)
1. **Control Panel → Task Scheduler → Create → Scheduled Task → User-defined script**
2. **General Settings:**
   - Task: `DSM-Config-Export`
   - User: `root`
3. **Schedule:** Daily at 3:00 AM
4. **Task Settings → Run command:**
   ```bash
   # Requires script to be on Synology
   cd /volume1/docker/synology-dsm-export
   python3 dump_dsm_settings.py
   ```

### Cloud Backup
```bash
# After export, sync to cloud
rclone sync out/ remote:backups/synology-configs/
```

---

## Security Considerations

⚠️ **This backup contains sensitive information:**
- Internal IP addresses
- Server names and serial numbers
- Usernames (but not passwords)
- Network topology

**Protect this file:**
- Store in encrypted location
- Do NOT commit to public git repos
- Share only with trusted administrators

**Cleanup after use:**
```bash
# Remove temporary .env file
rm scripts/synology-dsm-export/.env

# Secure the exported files
chmod 600 *.json
```

---

## Need Help?

- **Script documentation:** `../scripts/synology-dsm-export/README.md`
- **Current live config:** `../Synology Overview.md`
- **HomeLab documentation:** `../../Home.md`

---

*Last updated: 2026-04-20 by automated export*
