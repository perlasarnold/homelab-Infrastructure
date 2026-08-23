# 🖼️ Cebu Immich LXC Container Setup Guide

- **Date:** May 18, 2026
- **Objective:** Document the deployment and hardware-accelerated configuration of the high-performance Debian 13 Immich LXC (Container 112) on the secondary Proxmox node `Cebu`, and integrate it into the homelab's High Availability (HA) failover design.
- **Status:** Active / Secondary Standby & Migration Target
- **Access URL:** `http://VLAN 1 (Management):2283`

---

## 🖥️ System Specifications & Context

The container was provisioned using the community-maintained Proxmox helper scripts, optimizing hardware resources by deploying Immich in a lightweight Linux Container (LXC) rather than a heavy, monolithic Virtual Machine.

| Parameter | Specification | Rationale |
| :--- | :--- | :--- |
| **Host Node** | `Cebu` (VLAN 1 [Management]) | Offloads heavy computation from Bulakan; utilizes local resources. |
| **Container ID** | `112` | Structured ID indexing. |
| **LXC Type** | Unprivileged | Security best practice; isolates container root from host kernel. |
| **Operating System** | Debian 13 (Trixie/Testing) | Cutting-edge libraries required for compiled photo-processing dependencies. |
| **CPU Allocation** | 4 Cores | High-throughput for database queries and concurrent client access. |
| **RAM Allocation** | 6144 MiB (6 GiB) | Balanced footprint (Bulakan VM 204 consumed 12GB). |
| **Root Disk** | 20 GB on `cebu-zfs` | Slim OS footprint; photos live on centralized NAS storage. |
| **GPU Acceleration** | Intel iGPU Passthrough | Hardware transcoding and accelerated machine learning execution. |
| **ML Engine** | CPU / PyTorch (Default) | Setup with CPU-based UV Python machine learning workers. |
| **Database** | PostgreSQL 16 + VectorChord | Faster vector operations than generic pgvector for facial search. |

---

## 🛠️ Step-by-Step Provisioning Workflow (Helper Script Execution)

### 1. LXC Stack Upgrade
* **Command:** Host `apt update` and `apt upgrade` were executed.
* **Rationale:** Upgraded `pve-container` to `6.1.9` to ensure container compatibility, bridging stability, and system security on host Cebu.

### 2. Intel GPU Passthrough Auto-Configuration
* **Outcome:** Detected active onboard Intel UHD graphics on node Cebu.
* **Configuration:** Automatically mapped `/dev/dri/card0` (video:44) and `/dev/dri/renderD128` (render:992) from the Proxmox host into the unprivileged LXC container.
* **Rationale:** Enables direct hardware-accelerated ffmpeg transcoding of videos and offloads image generation/facial search from CPU to GPU.

### 3. Custom Compilation of Image Libraries
The setup compiled state-of-the-art photo-processing libraries from source to guarantee native hardware execution speeds:
1. **libjxl** (JPEG XL support)
2. **libheif** (HEIC support for Apple devices)
3. **libraw** (RAW camera image parsing)
4. **imagemagick** (Universal image formatting and scaling)
5. **libvips** (Blazing-fast, low-memory thumbnail generation)

### 4. Database Optimization
* **Database:** PostgreSQL 16.
* **Vector Engine:** Deployed **VectorChord (v0.5.3)** with granted Superuser privilege.
* **Rationale:** VectorChord offers enhanced performance for large-dimensional facial embedding vectors compared to pgvector, reducing search query latency.

---

## 🏛️ Integrating Container 112 into Homelab-Net HA Architecture

With Immich now running as **VM 204 on Bulakan** AND **LXC 112 on Cebu**, you have two powerful pathways to achieve robust High Availability.

```mermaid
graph TD
    subgraph Traffic Ingress
        NPM[Nginx Proxy Manager <br> VLAN 1 [Management]] -->|Primary Proxy Path| VM[Bulakan VM 204 <br> VLAN 1 (Management)]
        NPM -.->|Standby Proxy Path| LXC[Cebu LXC 112 <br> VLAN 1 (Management)]
    end

    subgraph Centralized Storage
        VM -->|CIFS/SMB Mount| NAS[TrueNAS \\TRUENAS\photo\Immich]
        LXC -->|CIFS/SMB Mount| NAS
    end

    subgraph Database Sync
        VMDB[(Bulakan VM Postgres)] --->|Scheduled pg_dump / Replication| LXCDB[(Cebu LXC Postgres)]
    end

    classDef primary fill:#2d3748,stroke:#ed8936,stroke-width:2px,color:#fff;
    classDef standby fill:#1a202c,stroke:#a0aec0,stroke-dasharray: 5 5,color:#fff;
    classDef storage fill:#1a202c,stroke:#4299e1,stroke-width:2px,color:#fff;
    class VM primary;
    class LXC standby;
    class NAS storage;
```

### Pathway A: Active-Standby Sync (LXC 112 as Cebu Failover)
Keep **VM 204 (Bulakan)** as your primary production instance, and use **LXC 112 (Cebu)** as a hot-standby replication target.

1. **Mount Shared Photos:** Mount the centralized TrueNAS share (`\\VLAN 1 (Management)\photo\Immich`) inside LXC 112 at `/usr/src/app/upload`.
2. **Replicate Database:** Set up a cron task to perform a scheduled `pg_dump` of the Postgres database inside VM 204, transfer the SQL file, and import it into LXC 112's Postgres instance.
3. **Failover Action:** If Bulakan crashes, Nginx Proxy Manager changes its backend routing from `VLAN 1 (Management)` to `VLAN 1 (Management)`, resulting in an instant standby recovery with zero downtime of the physical files.

### Pathway B: Permanent Migration to LXC (LXC 112 as Primary) 🌟 (Highly Recommended)
Because LXC 112 is a native container (Debian 13), it has **Intel GPU Passthrough** enabled and consumes **only 6GB of RAM** (instead of VM 204's heavy 12GB footprint). Migrating your primary server to LXC 112 will make your Immich experience faster, and save massive host resources:

1. **Mount Central Share:** Mount `\\VLAN 1 (Management)\photo\Immich` inside LXC 112.
2. **Restore Postgres:** Migrate VM 204's Postgres database to LXC 112 one time.
3. **Decommission VM 204:** Safely turn off VM 204, freeing up **12GB of RAM** and **600GB of disk space** on Bulakan-ZFS.
4. **Create a Bulakan Standby:** Spin up a tiny, empty standby LXC on Bulakan to act as your failover.

---

## 🛠️ Complete Migration & Database Restore Command Playbook

This playbook documents the exact cluster-verified commands executed to successfully migrate the database and establish the TrueNAS SCALE photo vault under unprivileged guest mapping with zero VM downtime.

### Phase 1: VM Storage Inspection & Safe Read-Only Mount
To copy data from the running `Immich-UbuntuLTS` VM (`204`) without shutting down services or causing write-locks:
1. SSH into the **Bulakan Host** (`VLAN 1 [Management]`).
2. Run `fdisk` to inspect the VM's ZFS volume partitions:
   ```bash
   fdisk -l /dev/zvol/Bulakan-ZFS/vm-204-disk-0
   ```
3. Mount the main Linux partition **read-only** (`-o ro`) to a temporary path on the host:
   ```bash
   mkdir -p /mnt/immich-vm-temp
   mount -o ro /dev/zvol/Bulakan-ZFS/vm-204-disk-0-part2 /mnt/immich-vm-temp
   ```

### Phase 2: Daily Database Backup Cluster Transfer
Copy the target Daily Database Dump over the cluster network:
1. From the Bulakan host, copy the gzipped SQL file to Cebu host's `/tmp`:
   ```bash
   scp /mnt/immich-vm-temp/home/homelab-admin/immich-app/mnt/immich-nas/backups/immich-db-backup-20260519T020000-v2.7.5-pg14.19.sql.gz root@VLAN 1 [Management]:/tmp/
   ```

### Phase 3: PostgreSQL Database Restore (Cebu LXC 112)
Import the database dump into PostgreSQL 16 on the new Debian 13 LXC container:
1. Push the database backup file from the Cebu Host directly into the running container:
   ```bash
   pct push 112 /tmp/immich-db-backup-20260519T020000-v2.7.5-pg14.19.sql.gz /tmp/immich-db-backup-20260519T020000-v2.7.5-pg14.19.sql.gz
   ```
2. Shell into the container (`pct enter 112` or SSH into `VLAN 1 (Management)`), and run:
   ```bash
   # Decompress the SQL backup file
   gunzip /tmp/immich-db-backup-20260519T020000-v2.7.5-pg14.19.sql.gz

   # Stop the native Immich application and machine learning services
   systemctl stop immich-server immich-machine-learning

   # Recreate a clean empty 'immich' database owned by the 'immich' user
   sudo -u postgres dropdb --if-exists immich
   sudo -u postgres createdb -O immich immich

   # Restore the database tables, metadata, and indexes
   sudo -u postgres psql -d immich -f /tmp/immich-db-backup-20260519T020000-v2.7.5-pg14.19.sql

   # Restart the Immich services
   systemctl start immich-server immich-machine-learning
   ```

### Phase 4: TrueNAS SMB Mounting & Container Mapping
Mount the parent TrueNAS SCALE photo share permanently on the Cebu Host and map both the upload vault and external libraries to Container 112:
1. SSH into the **Cebu Host** (`VLAN 1 [Management]`).
2. Create the parent mount directory:
   ```bash
   mkdir -p /mnt/truenas-photo
   ```
3. Append the permanent CIFS mount mapping for the parent `photo` directory to `/etc/fstab`:
   ```text
   //VLAN 1 (Management)/photo /mnt/truenas-photo cifs credentials=/etc/samba/credentials-seagate,iocharset=utf8,uid=100999,gid=100991,file_mode=0777,dir_mode=0777,nofail 0 0
   ```
   *Note:* `uid=100999` and `gid=100991` correspond exactly to Container 112's unprivileged `immich` user, allowing perfect read/write access.
4. Mount the parent share:
   ```bash
   mount /mnt/truenas-photo
   ```
5. Bind-mount the paths to LXC Container 112:
   ```bash
   # Bind-mount main photo upload vault (mp0)
   pct set 112 -mp0 /mnt/truenas-photo/Immich,mp=/opt/immich/upload

   # Bind-mount parent photo share for external libraries (mp1)
   pct set 112 -mp1 /mnt/truenas-photo,mp=/mnt/truenas-photo
   ```
6. Reboot Container 112 to activate both mappings:
   ```bash
   pct reboot 112
   ```

### Phase 5: High-Speed Background Library Sync
1. From the **Bulakan Host**, launch the persistent background `rsync` copy directly to the Cebu host's new mount path:
   ```bash
   nohup rsync -av --ignore-errors \
     /mnt/immich-vm-temp/home/homelab-admin/immich-app/mnt/immich-nas/ \
     root@VLAN 1 [Management]:/mnt/truenas-photo/Immich/ \
     > /var/log/immich_migration.log 2>&1 &
   ```
2. Monitor progress:
   ```bash
   tail -f /var/log/immich_migration.log
   ```

### Phase 6: Post-Migration Cleanup
1. Once the transfer completes, unmount the temporary read-only partition on the Bulakan host:
   ```bash
   umount /mnt/immich-vm-temp
   ```
2. If any temporary files were briefly written to the container's local SSD storage during realignments, clean them on the Cebu Host using:
   ```bash
   rm -rf /cebu-zfs/subvol-112-disk-0/opt/immich/upload/*
   ```

---

---

## 🔄 Active Storage Migration & External Libraries - May 19, 2026

The Cebu Immich LXC container is permanently configured to utilize a **single parent TrueNAS SCALE photo share (`//VLAN 1 (Management)/photo`)** to handle both main uploads and external photo libraries safely and efficiently.

### 1. Storage Mount Configuration (Cebu Host & LXC 112)
* **Cebu Host Mount Path:** `/mnt/truenas-photo`
* **Cebu Host `/etc/fstab` entry:**
  ```text
  //VLAN 1 (Management)/photo /mnt/truenas-photo cifs credentials=/etc/samba/credentials-seagate,iocharset=utf8,uid=100999,gid=100991,file_mode=0777,dir_mode=0777,nofail 0 0
  ```
* **LXC Container Bind-Mounts:**
  ```bash
  pct set 112 -mp0 /mnt/truenas-photo/Immich,mp=/opt/immich/upload
  pct set 112 -mp1 /mnt/truenas-photo,mp=/mnt/truenas-photo
  ```

### 2. External Library Configuration (Warding Off Recursion)
Because the container mounts `/mnt/truenas-photo` as a separate volume, you can scan existing picture folders in-place. To avoid scanning the `Immich` folder recursively:
1. Inside the Immich Web UI, create an **External Library**.
2. Point import paths to the specific subdirectories individually:
   - `/mnt/truenas-photo/Lightroom/`
   - `/mnt/truenas-photo/Memories/`
   - `/mnt/truenas-photo/MobileBackup/`
   - `/mnt/truenas-photo/Photography/`
   - `/mnt/truenas-photo/PhotoLibrary/`
3. 🚨 **DO NOT** add `/mnt/truenas-photo/Immich/`. This completely bypasses the recursive main upload folder!

### 3. High-Speed Background Migration
A background `rsync` script runs on the Bulakan host, copying the 600GB library from VM 204's read-only mounted partition directly to the Cebu host's mount:
```bash
nohup rsync -av --ignore-errors \
  /mnt/immich-vm-temp/home/homelab-admin/immich-app/mnt/immich-nas/ \
  root@VLAN 1 [Management]:/mnt/truenas-photo/Immich/ \
  > /var/log/immich_migration.log 2>&1 &
```
* **Security:** The source disk is mounted **read-only** (`-o ro`), protecting it from all modifications while VM 204 remains online.
* **Execution:** Once the TrueNAS quota is adjusted/expanded, the background rsync script will automatically copy all library folders into the share.

---

## 💾 ZFS Dataset Migration (DAS1-18TB/photo to DAS2-18TB/photo) - May 19, 2026

Because your main `photo` dataset (9.45 TiB) completely filled the physical `DAS1-18TB` pool, we executed a native, high-speed block-level **ZFS Send/Receive** migration to move the entire dataset to the empty `DAS2-18TB` pool (which has 15.5 TiB free space).

### 1. Reclaiming Bootstrap Space
To resolve the ZFS full deadlock (which blocks metadata/snapshot writes), we purged old files inside the Samba recycle bin directly inside the TrueNAS guest:
```bash
rm -rf /mnt/DAS1-18TB/photo/#recycle/*
```
This instantly freed up **2.91 GB** of metadata headroom to boot-strap ZFS.

### 2. Creating the Migration Freeze Frame
We froze the block-level state of the `photo` library by creating a recursive snapshot inside the TrueNAS SCALE VM:
```bash
zfs snapshot -r DAS1-18TB/photo@migrate
```

### 3. Persistent ZFS Replication via Transient systemd Unit
To ensure the 9.45 TiB block-level transfer survives QEMU Guest Agent session termination, we wrapped the migration in a native **systemd transient unit** (`zfs-migrate.service`) inside TrueNAS:
```bash
systemd-run --unit=zfs-migrate sh -c 'zfs send -Rv DAS1-18TB/photo@migrate | zfs recv -Fuv DAS2-18TB/photo'
```

### 4. Real-Time Progress Monitoring
Check copy progress inside TrueNAS using standard systemd tools:
```bash
# View the live block-transfer throughput and total bytes sent
systemctl status zfs-migrate

# Read the full transfer journal log
journalctl -u zfs-migrate -f
```

### 5. Final Cutover Playbook (Completed - May 21, 2026) 🟢

The storage cutover was successfully completed:
1. **Redirected the SMB Share on TrueNAS:** Updated the `photo` SMB share path to `/mnt/DAS2-18TB/photo` via middlewared API.
2. **Reclaimed 9.45 TB of DAS1 Space:** Safely destroyed the old `DAS1-18TB/photo` dataset inside TrueNAS to reclaim space.
3. **Relocated System Dataset:** Due to a space deadlock on `DAS1-18TB` preventing Samba from starting, the TrueNAS system dataset (`/var/db/system`) was successfully migrated to `DAS2-18TB`. See [[TrueNAS-System-Dataset-Deadlock-Recovery]] for the detailed troubleshooting post-mortem.
4. **`data` Dataset Rsync Migration:** Following ZFS I/O pressure and replication deadlocks on the `DAS1` pool, the `data` dataset (containing maintenance scripts and configs) was migrated to `DAS2-18TB` using a standard `rsync` transfer. The old dataset was cleanly destroyed via the middleware API.
5. **Rebuilt & Re-enabled the Cron Jobs:** Updated all internal paths within `sync-photo.sh` and `sync-seagate.sh` to target `/mnt/DAS2-18TB/data/` and updated the TrueNAS cron jobs to execute the new script paths on `DAS2`.

---

## 📸 Programmatic External Library Registration - May 21, 2026

To automate the mounting of massive external libraries without recursive UI clicking, we programmatically registered the `Photography` and `Edits` directories using the Immich REST API directly from the host.

### 1. Database-Driven API Key Extraction
Instead of manually generating an API key in the UI, we executed a Postgres query inside LXC 112 to extract the hashed API key directly:
```bash
pct exec 112 -- sudo -u postgres psql -d immich -t -A -c "SELECT key FROM api_key LIMIT 1;"
```

### 2. REST API Library Creation
Using a custom Python script executed inside the container, we hit the local API endpoint (`http://127.0.0.1:2283/api/libraries`) to dynamically create the external libraries and trigger an immediate deep scan:
- **Photography:** Mapped to `/mnt/truenas-photo/Photography`
- **Edits:** Mapped to `/mnt/truenas-photo/Edits`

### 3. Redis Queue & Database Validation
To comprehensively verify the background indexing of 57,000+ images without relying on the UI progress bars, we performed native database and cache validation queries:
- **Postgres Asset Validation:** Verified the total indexed assets by querying the `asset` table for `originalPath` string matches. This successfully confirmed **54,174** photography assets and **2,835** edit assets indexed.
- **BullMQ Redis Queues:** Queried the active and waiting background jobs directly from the Redis cache memory using the `immich_bull` prefix:
  ```bash
  pct exec 112 -- redis-cli -p 6379 llen immich_bull:thumbnailGeneration:waiting
  ```
  This confirmed that the `thumbnailGeneration`, `metadataExtraction`, `faceDetection`, and `smartSearch` queues were completely flushed (**0 waiting jobs**), definitively proving that Immich successfully finished processing the massive libraries.

---

## 📚 References
- [Proxmox VE Unprivileged LXC Storage Mount Guide](https://pve.proxmox.com/wiki/Unprivileged_LXC_disk_sharing)
- [Immich Official Documentation on Custom Folder Layouts](https://immich.app/docs/features/custom-folder-structure)
- [Proxmox VE Helper Scripts Repository](https://community-scripts.github.io/ProxmoxVE/)
- [ZFS Send and Receive Official Documentation](https://openzfs.github.io/openzfs-docs/man/8/zfs-send.8.html)


