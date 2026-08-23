# Bulakan — Proxmox VE 8 → VE 9 Upgrade Guide

> **Date:** Prepared 2026-07-17; executed 2026-07-23  
> **Node:** Bulakan (`192.168.1.25`) — Homelab-Net Cluster  
> **Objective:** In-place major version upgrade from Proxmox VE 8.4 to Proxmox VE 9 (Debian 13 "Trixie")  
> **Maintainer:** Perlas  

---

## Overview

Proxmox VE 9 is based on Debian 13 "Trixie" and was released in August 2025. This guide performs an **in-place upgrade**, meaning no reinstall is required. Cebu remains fully operational throughout to maintain cluster quorum and serve as a failover target.

**Estimated Total Time:** 3–5 hours (most time is backup creation)

---

## ⚠️ Before You Begin

### Warnings

- **cgroup v2 is now mandatory in PVE 9.** Very old container distros (CentOS 7, Ubuntu 16.04, Debian 9) may break. Review your LXC list before proceeding.
- **Bulakan ZFS is at ~86% capacity.** Clean up old snapshots or backups first to ensure ZFS has enough headroom.
- **All Bulakan services will go offline during reboot.** Plan a maintenance window with low-traffic impact.
- **Do NOT upgrade Cebu at the same time.** Upgrade nodes one at a time to maintain cluster availability.
- **There is no easy rollback** once `apt dist-upgrade` completes. Your backups are the only recovery path.

### Services that will be offline during the upgrade reboot

| ID | Name | Type |
|----|------|------|
| 100 | audiobookshelf | LXC |
| 101 | wireguard | LXC |
| 102 | nginxproxymanager-legacy | LXC |
| 103 | prowlarr | LXC |
| 104 | plex | LXC |
| 106 | sonarr | LXC |
| 107 | bazarr | LXC |
| 108 | jackett | LXC |
| 110 | jellyfin | LXC |
| 111 | photoprism | LXC |
| 112 | transmission | LXC |
| 115 | heimdall-dashboard | LXC |
| 118 | netbootxyz | LXC |
| 301 | piHole | LXC |
| 304 | cloudflared | LXC |
| 201 | Perlas-W10 | VM |
| 204 | Immich-UbuntuLTS | VM |

---

## Phase 0 — Pre-Upgrade Checks

### Step 1: Verify cluster health

SSH into Bulakan and confirm both nodes are online and quorum is healthy:

```bash
pvecm status
```

Expected output includes `Quorum information` with `Quorate: Yes` and both nodes listed as online.

Also check the current PVE version:

```bash
pveversion -v
```

You should be on `pve-manager/8.4.x` or later.

### Step 2: Check ZFS disk space

```bash
zpool list
zfs list | sort -k 2 -h -r | head -20
df -h /
```

If `Bulakan-ZFS` is above 85%, delete old snapshots or purge completed backups from PNAS before continuing.

To list snapshots:
```bash
zfs list -t snapshot
```

To delete a snapshot:
```bash
zfs destroy <pool>/<dataset>@<snapshot-name>
```

### Step 3: Verify replication status

```bash
pvesr status
```

Confirm no jobs are stuck or failed. Let any in-progress replication finish before proceeding.

---

## Phase 1 — Backup All VMs and Containers

> [!IMPORTANT]
> Do NOT skip this step. There is no rollback after the dist-upgrade starts. These backups are your only recovery path.

### Option A: Backup via Proxmox Web UI

1. Navigate to `https://192.168.1.25:8006`
2. Go to **Datacenter → Backup**
3. Create a backup job targeting all VMs/containers on Bulakan
4. Set storage to **PNAS** (or **DAS4-Backups** via Cebu)
5. Set mode to **Snapshot** (to avoid shutting down services)
6. Run the job and wait for all backups to complete

### Option B: Backup via CLI

```bash
vzdump --all --storage PNAS --mode snapshot --compress zstd
```

Replace `PNAS` with your actual backup storage ID as shown in `pvesm status`.

### Verify backups

Check the PNAS or backup storage to confirm each backup `.vma.zst` file exists and has a non-zero size.

### Backup Execution Record — 2026-07-23

The pre-upgrade backup completed before the planned maintenance window.

Configuration backup:

- Archive: `PNAS:backup/bulakan-host-config-20260723-074555.tar.gz`
- SHA-256: `cc2cc31da02fe78923d59f0fc207d74fceb028ffe69c189b4ee4084b55e41f29`
- The copied SQLite cluster database and live source database both passed `PRAGMA integrity_check`.
- The archive was opened successfully and contains `/etc/pve`, network, APT, bootloader, storage, package, ZFS, and guest inventory data.

Fresh protected backups were verified for every guest that was running:

| ID | Guest | Type | Result |
|---|---|---|---|
| 100 | audiobookshelf | LXC | Protected archive; metadata readable |
| 104 | plex | LXC | Protected archive; metadata readable |
| 108 | jackett | LXC | Protected archive; metadata readable |
| 110 | jellyfin | LXC | Protected archive; metadata readable |
| 113 | calibre-web | LXC | Protected archive; metadata readable |
| 115 | heimdall-dashboard | LXC | Protected archive; metadata readable |
| 203 | Bastion | VM | Protected archive; VMA configuration readable |
| 204 | Immich-UbuntuLTS | VM | Protected 471.28 GB archive; VMA configuration readable |
| 301 | pihole | LXC | Protected archive; metadata readable |
| 304 | cloudflared | LXC | Protected archive; metadata readable |

The owner explicitly requested that stopped guests be skipped. Do not treat the lack of a new archive for VM 202, CT 302, or VM 305 as a backup failure. Stopped CTs 102, 106, 107, and 118 had already completed before that instruction; their protected archives were retained rather than deleted.

The backup used snapshot mode, an 80 MiB/s bandwidth limit, low I/O priority, Zstandard compression, and `keep-all` retention. Running guests remained online. The final targeted job for VM 204, CT 301, and CT 304 completed successfully at 2026-07-23 11:13:51 PDT.

PNAS remained mounted throughout. After completion it had approximately 4.64 TiB available. Bind-mounted external media paths were inventoried but were not included in LXC root-filesystem archives.

---

## Phase 2 — Prepare the Node

### Step 1: Fully update PVE 8

Ensure Bulakan is at the latest PVE 8.x patch before upgrading:

```bash
apt update && apt full-upgrade -y
```

If a new kernel was installed, reboot:

```bash
reboot
```

After reboot, SSH back into Bulakan and confirm you're on the latest version:

```bash
pveversion -v
```

### Step 2: Run the official upgrade checker

Proxmox provides a dedicated tool to catch incompatibilities before you upgrade:

```bash
pve8to9 --full
```

Read the full output carefully:

| Symbol | Meaning |
|--------|---------|
| `PASS` | No issue found |
| `INFO` | Informational, no action required |
| `WARN` | Review — may cause issues |
| `CRITICAL` | **Must fix before upgrading** |

**Do not continue until all `CRITICAL` items are resolved.**

Common issues flagged by `pve8to9`:
- Kernel command line arguments that need updating
- Old PVE config file syntax in `/etc/pve/`
- Legacy LXC template versions
- Third-party or misconfigured APT repository entries

---

## Phase 3 — Update APT Repositories

### Step 1: Update the base Debian sources

Replace `bookworm` (Debian 12) with `trixie` (Debian 13) in the main sources list:

```bash
sed -i 's/bookworm/trixie/g' /etc/apt/sources.list
```

### Step 2: Update PVE and third-party sources

```bash
sed -i 's/bookworm/trixie/g' /etc/apt/sources.list.d/*.list
```

### Step 3: Verify the changes

```bash
cat /etc/apt/sources.list
cat /etc/apt/sources.list.d/*.list
```

Your PVE repo line should now read one of:

- **No-subscription:** `deb http://download.proxmox.com/debian/pve trixie pve-no-subscription`
- **Enterprise:** `deb https://enterprise.proxmox.com/debian/pve trixie pve-enterprise`

> [!TIP]
> If you have any custom `.list` files (e.g., for third-party packages), review those individually to confirm `trixie` is the correct target release for each.

---

## Phase 4 — Perform the Upgrade

### Step 1: Open a tmux session

Protect against SSH disconnection mid-upgrade:

```bash
tmux new -s upgrade
```

If you get disconnected, reconnect with:
```bash
tmux attach -t upgrade
```

### Step 2: Refresh package index

```bash
apt update
```

Review the output. You should see packages from `trixie` being fetched. Look for any errors or `404 Not Found` messages — these indicate a bad repo URL. Fix before proceeding.

### Step 3: Start the dist-upgrade

```bash
apt dist-upgrade
```

This will take **30–60 minutes**. During the upgrade:

- You may be prompted about **modified config files**. Guidelines:
  - For system files you have **not customized**: accept the maintainer's version (press `Y` or choose "install maintainer's version")
  - For **network config** (`/etc/network/interfaces`) and **PVE configs** (`/etc/pve/`): keep your current version
- Do **not** close the tmux session or the terminal

---

## Phase 5 — Post-Upgrade Steps

### Step 1: Reboot Bulakan

```bash
reboot
```

Wait 2–3 minutes for the node to come back online.

### Step 2: Verify PVE 9

SSH back in and confirm the new version:

```bash
pveversion -v
uname -r
```

Expected:
- `pve-manager/9.x.x`
- Kernel version `6.x-pve`

### Step 3: Check cluster status

```bash
pvecm status
```

Both Bulakan and Cebu should be online with `Quorate: Yes`.

### Step 4: Check ZFS pool health

```bash
zpool status
zpool list
```

`Bulakan-ZFS` should show `ONLINE` with no errors.

### Step 5: Start services in order

Start critical services first to restore network-level functionality before starting media services:

```bash
# 1. DNS — start this first
pct start 301   # piHole

# 2. Tunnel & VPN
pct start 304   # cloudflared
pct start 101   # wireguard

# 3. Proxy
pct start 102   # nginxproxymanager-legacy

# 4. Media services
pct start 100   # audiobookshelf
pct start 104   # plex
pct start 110   # jellyfin
pct start 111   # photoprism

# 5. Arr stack
pct start 103   # prowlarr
pct start 106   # sonarr
pct start 107   # bazarr
pct start 108   # jackett
pct start 112   # transmission

# 6. Utilities
pct start 115   # heimdall-dashboard
pct start 118   # netbootxyz

# 7. VMs
qm start 201    # Perlas-W10
qm start 204    # Immich-UbuntuLTS
```

### Step 6: Verify each service

| Service | URL |
|---------|-----|
| Proxmox UI | https://192.168.1.25:8006 |
| Pi-Hole | http://192.168.1.4/admin |
| Plex | http://192.168.1.54:32400 |
| Jellyfin | http://192.168.1.126:8096 |
| Audiobookshelf | http://192.168.1.59 |

> [!TIP]
> Clear your browser cache before loading the Proxmox Web UI. The new interface may not render correctly with a cached version.

### Step 7: Check replication jobs

```bash
pvesr status
```

Confirm ZFS replication from Bulakan → Cebu has resumed successfully.

---

## Phase 6 — Cleanup

Remove packages that are no longer needed:

```bash
apt autoremove --purge
apt autoclean
```

Check for held packages:

```bash
apt-mark showhold
```

Check for leftover config files from removed packages:

```bash
dpkg -l | grep ^rc
```

If there are any, purge them:
```bash
dpkg -l | grep ^rc | awk '{print $2}' | xargs apt purge -y
```

---

## Rollback Plan

> [!CAUTION]
> A full in-place rollback to PVE 8 is **not possible** after `apt dist-upgrade` completes. Your options are:

| Scenario | Recovery Action |
|----------|----------------|
| Individual service broken post-upgrade | Restore that VM/LXC from PNAS backup |
| Bulakan unstable but Cebu OK | Start replicated VMs on Cebu temporarily |
| Bulakan unbootable | Reinstall PVE 9 fresh, restore all VMs/containers from PNAS backups |

---

## Post-Upgrade Verification Checklist

```
[x] pveversion shows pve-manager 9.2.5
[x] uname -r shows 7.0.14-6-pve
[x] pvecm status shows Quorate: Yes, both clustered nodes online
[x] zpool status reports all pools healthy
[x] pvesr status checked; no replication jobs are currently configured
[x] Pi-hole DNS resolves external names
[x] Plex identity endpoint and Jellyfin health endpoint respond
[x] Immich VM 204 is running; application-level login was not tested
[x] Cloudflared service is active
[x] Proxmox Web UI returns HTTP 200
```

---

## Outcome

### Execution record — 2026-07-23

Bulakan was upgraded successfully from Proxmox VE 8.4.19 on Debian 12 to
Proxmox VE 9.2.5 on Debian 13. The final running kernel is
`7.0.14-6-pve`.

Steps taken and rationale:

1. Verified the protected running-guest backups and created a fresh host
   rollback archive before modifying packages:
   - Archive:
     `PNAS:backup/bulakan-pre-pve9-20260723-122959.tar.gz`
   - SHA-256:
     `699014880190bf6ef10e29a004b37f38ea6cb0768a0c8a7dcd10a4b3f0a25e0a`
   - The archive passed a full `tar -tzf` readability check.
2. Removed only the obsolete `systemd-boot` meta-package, enabled GRUB's
   removable EFI path, and reinstalled `grub-efi-amd64`. This resolved the
   hard `pve8to9` bootloader failure.
3. Updated Bulakan fully within PVE 8 and rebooted into
   `6.8.12-37-pve`. This validated the repaired GRUB path before making
   the irreversible Debian 13 repository change.
4. Gracefully shut down all guests that were running before maintenance.
   Bastion VM 203 initially ignored ACPI because it has no QEMU guest
   agent; it was shut down cleanly from inside Windows.
5. Backed up and staged the APT source changes under
   `/root/pve9-stage-20260723`, reviewed the exact diff, then changed the
   active Debian and PVE no-subscription repositories from `bookworm` to
   `trixie`.
6. Simulated the full transaction and confirmed that the `proxmox-ve`
   meta-package would upgrade to 9.2.0 rather than be removed.
7. Ran the distribution upgrade in the persistent
   `bulakan-pve9-upgrade.service` unit. The transaction completed with exit
   status 0: 696 packages upgraded, 166 installed, and 65 obsolete
   Bookworm libraries replaced or removed.
8. Rebooted into PVE 9 and allowed Proxmox's configured startup order to
   restore the original running guest set.
9. Removed the obsolete `vfio_virqfd` line from `/etc/modules`. Kernel 7.0
   includes that functionality elsewhere, while `vfio`,
   `vfio_iommu_type1`, and `vfio_pci` continue to load.

Verified outcome:

- `pve-manager/9.2.5` and kernel `7.0.14-6-pve`
- APT and dpkg clean, with zero pending upgrades
- No failed host systemd units
- Homelab-Net quorate with Bulakan and Cebu online
- `Bulakan-ZFS` online and healthy; 86.61% used
- PNAS active over SMB 3.1.1 with an isolated read/write test completed
- Proxmox web UI returned HTTP 200
- Running VMs restored: 203 and 204
- Running LXCs restored: 100, 104, 108, 110, 113, 115, 301, and 304
- Guests that were stopped before maintenance remained stopped
- Pi-hole DNS, Plex, Jellyfin, Audiobookshelf, Jackett, and Cloudflared
  service checks passed

Follow-up items:

- `intel-microcode` remains optional but recommended. Add Debian's
  `non-free-firmware` component and install it during a future reboot
  window.
- Keep monitoring `Bulakan-ZFS`; 86.61% usage leaves limited ZFS
  headroom.
- CTs 100, 108, 115, and 304 report the common LXC
  `sys-kernel-config.mount` failure while their application services are
  active. CT 115 also reports a non-critical `systemd-logind` failure.
- Do not run `apt autoremove` until the PVE 9 host has remained stable long
  enough to confirm that the older fallback kernels are no longer needed.

---

## References

- [Proxmox VE 9 Release Notes](https://pve.proxmox.com/wiki/Roadmap)
- [Official Proxmox Upgrade from 8 to 9 Wiki](https://pve.proxmox.com/wiki/Upgrade_from_8_to_9)
- [Proxmox APT Repository Info](https://pve.proxmox.com/wiki/Package_Repositories)
- [Bulakan Proxmox Overview](../02-Proxmox/Proxmox%20Overview.md)
