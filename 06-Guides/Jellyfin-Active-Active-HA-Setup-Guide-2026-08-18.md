# 🎬 Jellyfin Active-Active High Availability (HA) Setup Guide

**Date:** 2026-08-18  
**Objective:** Establish zero-downtime Active-Active High Availability (HA) for Jellyfin across Proxmox nodes (**Bulakan CT 110** and **Dapitan CT 510**) with continuous watch progress synchronization, single unified reverse proxy routing (`jellyfin.homelab-admin.me`), and automated health-check failover via **Cebu Nginx Proxy Manager (CT 105)**.

---

## 1. Architecture & Design Principles

```
                             [ Clients / Smart TVs / Mobile Apps ]
                                               │
                                               ▼
                           [ Unified URL: jellyfin.homelab-admin.me ]
                                               │
                                               ▼
                         [ Cebu NPM (192.168.120.211) Reverse Proxy ]
                          • Sticky IP Hash session affinity
                          • Health check routing (5s failover timeout)
                                               │
                        ┌──────────────────────┴──────────────────────┐
                        │ (Primary Node)                              │ (Standby / Backup)
                        ▼                                             ▼
           ┌─────────────────────────┐                   ┌─────────────────────────┐
           │   Bulakan Jellyfin CT   │                   │   Dapitan Jellyfin CT   │
           │  (192.168.110.41:8096)  │                   │  (192.168.110.43:8096)  │
           │  • Local SQLite DB      │                   │  • Local SQLite DB      │
           │  • Local Transcoder     │                   │  • Local Transcoder     │
           └────────────┬────────────┘                   └────────────┬────────────┘
                        │                                             │
                        │         ┌─────────────────────────┐         │
                        └────────►│  Jellyfin Watch Sync    │◄────────┘
                                  │  REST API State Sync    │
                                  └─────────────────────────┘
                                               │
                        ┌──────────────────────┴──────────────────────┐
                        ▼                                             ▼
           [ PNAS Synology Shared Mount ]                [ Dapitan 18TB ZFS Storage ]
             /mnt/synology/share/movies/                   /mnt/bindmounts/media-data/...
```

### Why Independent SQLite Instances?
Pointing two active Jellyfin instances to the exact same `/config` folder over NFS/SMB corrupts SQLite (`SQLITE_BUSY` write-lock collisions). By running independent instances with identical user accounts and syncing play states via the Jellyfin REST API, each node maintains database integrity while providing instant, seamless failover.

---

## 2. Infrastructure Parameters

| Parameter | Primary Instance | Secondary Instance | Reverse Proxy |
| :--- | :--- | :--- | :--- |
| **Proxmox Node** | Bulakan (`192.168.1.25`) | Dapitan (`192.168.1.27`) | Cebu (`192.168.1.26`) |
| **Container ID** | `CT 110` | `CT 510` | `CT 105` |
| **VLAN & IP** | `192.168.110.41:8096` (VLAN 110) | `192.168.110.43:8096` (VLAN 110) | `192.168.120.211:81` (VLAN 120) |
| **Host Names** | `jellyfin` | `jellyfin-dapitan` | `npm-cebu` |
| **Public Endpoint** | `https://jellyfin.homelab-admin.me` | `https://jellyfindp.homelab-admin.me` (direct alias) | `homelab-admin.me` |

---

## 3. Step-by-Step Implementation

### Step 1: Align User Accounts & Library Paths
1. Log into **Bulakan Jellyfin** (`http://192.168.110.41:8096`) and **Dapitan Jellyfin** (`http://192.168.110.43:8096`).
2. Verify that user accounts exist on both servers with identical usernames (e.g. `admin`, `family`).
3. Ensure both servers index the same media library folder structure:
   - Movies: `/media/movies` (or `/media/library/movies`)
   - TV Shows: `/media/tv` (or `/media/library/tv`)

---

### Step 2: Configure NPM Upstream Failover Block on Cebu

On **Cebu NPM** (`192.168.120.211`):

1. Access the NPM console / SSH into Cebu CT 105 (`pct exec 105 bash`).
2. Create an Nginx custom configuration file at `/data/nginx/custom/http_top.conf`:
   ```bash
   cat << 'EOF' > /data/nginx/custom/http_top.conf
   upstream jellyfin_ha_cluster {
       ip_hash;
       server 192.168.110.41:8096 max_fails=2 fail_timeout=5s;
       server 192.168.110.43:8096 max_fails=2 fail_timeout=5s backup;
   }
   EOF
   ```

3. In the NPM Web Admin UI (`http://192.168.120.211:81`), edit the **Proxy Host** for `jellyfin.homelab-admin.me` / `media.homelab-admin.me`:
   - **Details Tab**:
     - **Forward Scheme**: `http`
     - **Forward Hostname / IP**: `jellyfin_ha_cluster`
     - **Forward Port**: `8096`
     - **Websockets Support**: `ON`
   - **SSL Tab**:
     - **Certificate**: `*.homelab-admin.me` (Let's Encrypt Wildcard)
     - **Force SSL**: `ON`
     - **HTTP/2 Support**: `ON`
     - **HSTS Enabled**: `ON`
   - **Advanced Tab**:
     ```nginx
     # Jellyfin HA Streaming & Failover Directives
     client_max_body_size 0;
     proxy_buffering off;
     proxy_read_timeout 3600s;
     proxy_send_timeout 3600s;
     send_timeout 3600s;

     # Proxy Next Upstream Failover on Error
     proxy_next_upstream error timeout http_502 http_503 http_504;
     proxy_next_upstream_timeout 5s;
     proxy_next_upstream_tries 2;
     ```
4. Click **Save**. Test Nginx syntax and reload:
   ```bash
   nginx -t && nginx -s reload
   ```

---

### Step 3: Configure Automated 2-Way (Bidirectional) Watch Progress Synchronization

To continuously synchronize watch history, in-progress resume timestamps, and favorites bidirectionally across all 3 nodes (**Bulakan**, **Cebu**, and **Dapitan**):

1. **Shared API Authentication**:
   - Provisioned API token `<YOUR_JELLYFIN_API_KEY>` under `Jellyfin-2Way-Sync` across all three servers.

2. **High-Speed Bidirectional Sync Engine (`/usr/local/bin/jellyfin-2way-sync.py`)**:
   - Compares latest `LastPlayedDate` timestamps and `PlaybackPositionTicks` for each user (`homelab-admin`, `qtienzq`).
   - Propagates played status and favorite updates bidirectionally in $< 0.6\text{s}$ per cycle.

   ```python
   # /usr/local/bin/jellyfin-2way-sync.py
   # Automatically compares active user items and syncs newest played & favorite state.
   ```

3. **Automated 3-Minute Cron Job**:
   Deployed on **Cebu CT 416** (and mirrored on Dapitan CT 510):
   ```bash
   cat << 'EOF' > /etc/cron.d/jellyfin-2way-sync
   */3 * * * * root /usr/bin/python3 /usr/local/bin/jellyfin-2way-sync.py >> /var/log/jellyfin-sync.log 2>&1
   EOF
   ```

---

---

### Step 5: Automated Weekly Updates with 5-Point QA & Auto-Rollback

All Jellyfin servers are configured with an automated maintenance pipeline running **every Sunday at 3:00 AM** (staggered after Plex at 2:00 AM):

```bash
# Cron schedule on each Proxmox node (/etc/cron.d/jellyfin-auto-update):
0 3 * * 0 root /usr/local/bin/auto-update-jellyfin-qa-rollback.sh <CT_ID>
```

#### Automated Pipeline Workflow:
1. **Instantaneous ZFS Snapshot**:
   - Takes a native ZFS snapshot of the container rootfs (`<DATASET>@pre-upgrade-<TIMESTAMP>`) taking $< 0.1\text{s}$ and 0 extra storage.
2. **Package Upgrade**:
   - Upgrades `jellyfin`, `jellyfin-server`, `jellyfin-web`, and `jellyfin-ffmpeg` via official APT repositories.
3. **5-Point QA Health Verification Suite**:
   - ✅ **Check 1**: `systemd` unit active (`systemctl is-active jellyfin == active`)
   - ✅ **Check 2**: Health endpoint responds with `HTTP 200 OK` on `/health`
   - ✅ **Check 3**: Web UI responds with `HTTP 200 OK` on `/web/index.html`
   - ✅ **Check 4**: Jellyfin API `/System/Info/Public` returns valid JSON with `ServerName`
   - ✅ **Check 5**: Intel QuickSync GPU driver test (`vainfo`) succeeds under the `jellyfin` user
4. **Automated Rollback & Retention Engine**:
   - **If ALL 5 checks pass**: Retains pre-upgrade snapshot in a **rolling 4-snapshot buffer** (maximum 4 backups per container) and automatically prunes any snapshots older than 4 weeks.
   - **If ANY check fails (within 60s)**: Immediately rolls back the ZFS dataset to the pre-upgrade snapshot and restarts the container, restoring the previous working version with **0 manual intervention**.
5. **Audit Logging**:
   - Full logs tracked at `/var/log/jellyfin-auto-update.log` on each Proxmox host.

---

## 4. Verification & Testing Procedure

### Test 1: Active Upstream Routing
1. Open browser to `https://jellyfin.homelab-admin.me`.
2. Inspect the server name / network logs: Confirm response is served by **Bulakan CT 110** with `HTTP 200`.

### Test 2: Simulated Node Failover
1. On Bulakan Proxmox host (`192.168.1.25`), pause or stop CT 110:
   ```bash
   pct stop 110
   ```
2. Hard-refresh `https://jellyfin.homelab-admin.me`.
3. Verify that the webpage loads within < 2 seconds, served seamlessly by **Dapitan CT 510**.
4. Confirm media playback functions normally from Dapitan's local library.

### Test 3: Recovery & Restoration
1. Restart Bulakan CT 110:
   ```bash
   pct start 110
   ```
2. Confirm NPM automatically promotes Bulakan back to active primary duty with zero manual intervention.

---

## 5. Outcome & Rollback

- **Outcome**: High-availability active-active Jellyfin cluster established. If Bulakan fails or undergoes kernel maintenance, Dapitan immediately takes over with zero downtime and synchronized user watch states.
- **Rollback Procedure**: In NPM Web UI (`http://192.168.120.211:81`), edit `jellyfin.homelab-admin.me` and set the Forward Hostname statically back to `192.168.110.41`.

---

## 6. References
- [Nginx Proxy Manager Setup & Operations](../05-Services/Nginx%20Proxy%20Manager.md)
- [Dapitan Jellyfin Replication Guide](./Dapitan-Jellyfin-Replication-Guide-2026-07-24.md)
- [Jellyfin Direct Port Forwarding NPM Setup](./Jellyfin-Direct-Port-Forwarding-NPM-Setup-2026-08-14.md)
- [Guides Index](./Guides%20Index.md)
