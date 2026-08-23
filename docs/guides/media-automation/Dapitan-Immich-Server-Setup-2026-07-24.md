# 🖼️ Dapitan Immich Server Setup & Data Migration Guide

- **Date:** July 24, 2026
- **Objective:** Document the deployment and data migration of the headless Ubuntu 24.04 LTS Immich photo management server (Container 504 `immich-dapitan`) on Proxmox node `Dapitan`, utilizing the attached 18TB ZFS bulk storage pool (`bulk18/immich-data`).
- **Status:** Active / Production Primary
- **Access URL:** `http://192.168.1.147:2283`

---

## 🖥️ System Specifications & Infrastructure Topology

The Immich photo management server was provisioned as a lightweight, non-GUI (headless) Ubuntu 24.04 LTS container on host `Dapitan`, storing application metadata and PostgreSQL database tables on high-speed NVMe storage while utilizing the 18TB attached ZFS bulk storage dataset for all media assets.

| Parameter | Specification | Rationale |
| :--- | :--- | :--- |
| **Host Node** | `Dapitan` (192.168.1.27) | Node 3 in `Homelab-Net` cluster; offloads storage/compute from Bulakan. |
| **Container ID** | `504` | Structured 500-series guest ID indexing for Dapitan node. |
| **Hostname** | `immich-dapitan` | Descriptive hostname in local DNS. |
| **IP Address** | `192.168.1.147` | DHCP assigned static lease / container address. |
| **Operating System** | Ubuntu 24.04 LTS Server (Headless / CLI) | Non-GUI Linux LTS platform with modern kernel support. |
| **CPU Allocation** | 4 Cores | High-throughput for EXIF parsing, video processing, and face vector search. |
| **RAM Allocation** | 8192 MiB (8 GiB) | Memory footprint optimized for database & machine learning workers. |
| **Root Disk** | 32 GB on `vm-fast` | NVMe SSD ZFS pool (`vm-fast/vmdata`) for OS and high-IOPS PostgreSQL DB. |
| **18TB Asset Storage (`mp0`)** | `/mnt/bindmounts/immich-data` -> `/mnt/immich-nas` | Direct bind mount of host ZFS dataset `bulk18/immich-data` (16.2 TiB free). |
| **Database** | PostgreSQL 16 + VectorChord / pgvector | High-performance vector embeddings for face recognition. |

### Terminal Access

- **Console account:** `root`
- **Password authentication:** Configured and verified on 2026-07-24.
- **Password storage:** The password is intentionally not recorded in this
  repository.
- **Console troubleshooting:** After an initial console rejection, the root
  password was reset through an ASCII-safe input path and verified against
  the container's stored password hash. Any accumulated failed-login counter
  was cleared. No container or Immich service restart was required.
- **Proxmox host access:** From the Dapitan host shell, administrators can
  enter the container without a separate guest login:

  ```bash
  pct enter 504
  ```

- **Proxmox guest console:** Open **Dapitan → 504 (immich-dapitan) → Console**
  and sign in as `root` using the separately maintained password.

---

## 🛠️ Step-by-Step Provisioning & Migration Workflow

### Step 1: Storage Dataset & Mount Verification
- **Host Dataset**: Verified ZFS dataset `bulk18/immich-data` mounted at `/mnt/bindmounts/immich-data` with `recordsize=1M` and `zstd` compression.
- **Proxmox ZFS Allocator**: Configured `vm-fast/vmdata` mountpoint (`/vm-fast/vmdata`) for container rootfs allocation.

### Step 2: Guest Container Provisioning
1. Downloaded Ubuntu 24.04 LTS standard template (`ubuntu-24.04-standard_24.04-2_amd64.tar.zst`).
2. Created Container 504:
   ```bash
   pct create 504 local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst \
     --ostype ubuntu --hostname immich-dapitan \
     --cores 4 --memory 8192 --swap 2048 \
     --rootfs vm-fast:32 --features nesting=1,keyctl=1 \
     --unprivileged 0 --net0 name=eth0,bridge=vmbr0,ip=dhcp --onboot 1
   ```
3. Attached 18TB bulk storage dataset:
   ```bash
   pct set 504 -mp0 /mnt/bindmounts/immich-data,mp=/mnt/immich-nas
   ```
4. Configured AppArmor unconfined profile in `/etc/pve/lxc/504.conf`:
   ```text
   lxc.apparmor.profile: unconfined
   ```

### Step 3: Application Stack Setup (`/opt/immich`)
1. Installed Docker Engine 29.6 and Docker Compose plugin inside CT 504.
2. Created `/opt/immich/.env`:
   ```env
   UPLOAD_LOCATION=/mnt/immich-nas
   DB_DATA_LOCATION=./postgres
   IMMICH_VERSION=RELEASE
   DB_PASSWORD=postgres
   DB_USERNAME=postgres
   DB_DATABASE_NAME=immich
   ```
3. Created `/opt/immich/docker-compose.yml` with `security_opt: [ "apparmor:unconfined" ]` for Docker container execution.

### Step 4: Non-Disruptive Background Data Migration
1. **Source Mounting**: Mounted Bulakan VM 204 ZFS volume partition read-only at `/mnt/immich-vm-temp` on host Bulakan (`192.168.1.25`), keeping VM 204 online without write locks.
2. **Library Asset Transfer**: Executed `rsync` from Bulakan host directly to Dapitan's 18TB dataset `/mnt/bindmounts/immich-data/`:
   ```bash
   nohup rsync -av --info=progress2 \
     /mnt/immich-vm-temp/home/homelab-admin/immich-app/mnt/immich-nas/ \
     root@192.168.1.27:/mnt/bindmounts/immich-data/ \
     > /var/log/dapitan_immich_rsync.log 2>&1 &
   ```
   *Transferred:* **224.4 GB** total across `library`, `upload`, `thumbs`, `encoded-video`, `profile`, and `backups`.

### Step 5: Database Metadata Restoration
1. Extracted clean SQL backup file (`immich-db-backup-20260723T020000-v2.7.5-pg14.19.sql.gz`).
2. Recreated clean `immich` database in PostgreSQL:
   ```bash
   docker exec immich_postgres dropdb --if-exists -U postgres immich
   docker exec immich_postgres createdb -O postgres -U postgres immich
   ```
3. Restored database schema, tables, vector embeddings, EXIF metadata, and user accounts:
   ```bash
   docker exec -i immich_postgres psql -U postgres -d immich < /tmp/immich-db-backup.sql
   ```

---

## 📊 Post-Migration Verification & Health Check

### Database Integrity Audit
Query executed inside `immich_postgres` container on Dapitan:

| Metric | Migrated Record Count | Verification Status |
| :--- | :--- | :--- |
| **Total Photo & Video Assets** | `46,717` | Verified 100% match |
| **EXIF Metadata Records** | `46,717` | Verified 100% match |
| **Face Recognition Clusters** | `6,829` | Verified 100% match |
| **Albums** | `143` | Verified 100% match |
| **User Accounts** | `1` | Verified 100% match |

### Service Health
- **HTTP Endpoint**: `http://192.168.1.147:2283` returns `HTTP 200 OK`.
- **Container Services**: `immich_server`, `immich_machine_learning`, `immich_postgres`, `immich_redis` all reporting `healthy`.

### Network Outage and Live Repair

On 2026-07-24, an interactive `apt-get upgrade --fix-missing` stopped at
`Connecting to archive.ubuntu.com`, while the public Immich endpoint returned
HTTP 502.

Investigation showed:

- Immich returned HTTP 200 on `127.0.0.1:2283` inside CT 504.
- All four Immich Docker containers remained healthy.
- CT 504 could not ARP or ping gateway `192.168.1.1`.
- DNS resolution consequently timed out.
- The Dapitan host and CT 509 retained normal gateway connectivity.
- Host interface `veth504i0` was up but was no longer a member of `vmbr0`.

The live repair was:

```bash
ip link set dev veth504i0 master vmbr0
```

This restored the network without restarting CT 504, Docker, or Immich.
Post-repair verification confirmed:

- `veth504i0` was forwarding through `vmbr0`.
- CT 504 could reach `192.168.1.1`.
- `archive.ubuntu.com` resolved normally.
- Dapitan reached `http://192.168.1.147:2283` with HTTP 200.
- `https://immich.homelab-admin.me/` returned HTTP 200.

Rollback for the live bridge attachment, if ever required:

```bash
ip link set dev veth504i0 nomaster
```

The interrupted APT command exited before running `dpkg`. `dpkg --audit`
returned no findings, while 178 packages remained upgradable. Run a new
upgrade only during an approved maintenance window because package upgrades
can restart services.

The persistent Proxmox configuration already specifies `bridge=vmbr0` for
CT 504. A normal future container start should recreate the bridge
attachment; verify it with:

```bash
bridge link show dev veth504i0
```

---

## 🔒 Rollback & Maintenance Plan

1. **Bulakan VM 204 Safety**: Bulakan VM 204 remains unmodified and fully functional in a powered-up standby state. If required, proxy routing can be reverted instantly.
2. **Reverse Proxy Update**: Update Nginx Proxy Manager (`192.168.1.210`) upstream target for Immich from `192.168.1.154` to `192.168.1.147`.
3. **Decommissioning VM 204**: After 7 days of observation on Dapitan, VM 204 on Bulakan can be powered down to reclaim 12 GB RAM and 600 GB ZFS disk space.
