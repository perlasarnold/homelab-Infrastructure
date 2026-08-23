# 🎬 Plex Media Server Infrastructure

## Overview
Plex Media Server is deployed across multiple Proxmox LXC nodes in the homelab to provide resilient, hardware-accelerated media streaming across local LAN and external WAN networks.

---

## Cluster Topology & Nodes

| Node | Host CPU & GPU | CT ID | IP Address | Transcode Engine | Storage Backing |
| :--- | :--- | :---: | :---: | :---: | :--- |
| **Bulakan (Primary)** | Intel i5-9500T (UHD 630) | `104` | `192.168.1.54:32400` | Intel QSV + `/dev/shm` (16GB RAM) | Synology NAS (`PNAS`) SMB `/mnt/plex` & `/mnt/plex1` |
| **Cebu (High Perf)** | Intel i5-10500T (UHD 630) | `109` | `192.168.1.215:32400` | Intel QSV + `/dev/shm` (16GB RAM) | Synology NAS (`PNAS`) SMB `/mnt/plex` & `/mnt/plex1` |
| **Dapitan (DR & Direct)**| Intel i5-7500 (HD 630) | `509` | `192.168.110.44:32400` | Intel QSV + `/dev/shm` (20GB RAM) | ⚡ Direct-Attached 18TB SATA ZFS (`bulk18`, recordsize=1M) |

---

## ⚡ Performance Optimizations Applied

1. **Intel QuickSync Video (QSV) Hardware Acceleration**:
   - Passed `/dev/dri/card*` and `/dev/dri/renderD128` through to each LXC container with matching group permissions (`video:44` and `render:104`/`render:993`).
   - Enables real-time hardware decoding and encoding for HEVC (H.265) 10-bit, H.264, VP9, and MPEG-2 at 150–180+ FPS.
2. **RAM-Disk Transcoding (`/dev/shm/transcodes`)**:
   - Re-routed temporary video transcode segment buffers from SSD/ZFS storage to container memory `tmpfs` (`/dev/shm/transcodes`).
   - Eliminates SSD write endurance degradation and delivers instantaneous scrub/seek latency.
3. **Resource Sizing**:
   - Allocated 4 vCPUs and 4 GiB RAM to each Plex LXC container for heavy multi-stream concurrency.

---

## ⏰ Weekly Automated Updates with QA & Auto-Rollback

All Plex servers are configured with an automated maintenance pipeline running **every Sunday at 2:00 AM**:

```bash
# Cron schedule on each Proxmox node (/etc/cron.d/plex-auto-update):
0 2 * * 0 root /usr/local/bin/auto-update-plex-qa-rollback.sh <CT_ID>
```

### Automated Pipeline Workflow:
1. **Instantaneous Pre-Upgrade Snapshot**:
   - Takes a native ZFS snapshot of the container rootfs (`<DATASET>@pre-upgrade-<TIMESTAMP>`) taking $< 0.1\text{s}$ and 0 extra storage.
2. **Package Upgrade**:
   - Checks and applies the latest official `plexmediaserver` APT package inside the container.
3. **5-Point QA Health Verification Suite**:
   - ✅ **Check 1**: `systemd` unit active (`systemctl is-active plexmediaserver == active`)
   - ✅ **Check 2**: Web UI responds with `HTTP 200 OK` on `/web/index.html`
   - ✅ **Check 3**: Plex API `/identity` responds with valid `machineIdentifier`
   - ✅ **Check 4**: Intel QuickSync GPU driver test (`vainfo`) succeeds under the `plex` user
   - ✅ **Check 5**: RAM-disk transcode directory (`/dev/shm/transcodes`) is verified writable
4. **Automated Rollback & Retention Engine**:
   - **If ALL 5 checks pass**: Retains pre-upgrade snapshot in a **rolling 4-snapshot buffer** (maximum 4 backups per container) and automatically prunes any snapshots older than 4 weeks.
   - **If ANY check fails (within 60s)**: Immediately rolls back the ZFS dataset to the pre-upgrade snapshot and restarts the container, restoring the previous working version with **0 manual intervention**.
5. **Audit Logging**:
   - Full logs tracked at `/var/log/plex-auto-update.log` on each Proxmox host.
