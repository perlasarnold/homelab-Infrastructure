# 🖼️ Dapitan Immich Performance Optimization Guide

- **Date:** August 21, 2026
- **Objective:** Improve query speed, web/mobile client load latency, and media processing throughput for the Immich photo management server (Container 504 `immich-dapitan`) on Proxmox node `Dapitan`.
- **Target Instance:** `immich-dapitan` (`VLAN 110 (Services):2283` / `https://immich.homelab-admin.me/`)
- **Status:** Completed / Active

---

## 🔍 Performance Baseline & Bottleneck Analysis

An audit of the active Immich stack on Dapitan CT 504 identified several server-side bottlenecks affecting both LAN and remote access:

1. **CPU-Bound Media Processing:** Machine learning (face detection, Smart Search CLIP embeddings) and thumbnail generation are executed entirely on CPU cores due to missing `/dev/dri` GPU passthrough.
2. **PostgreSQL Default Configuration:** The `ghcr.io/immich-app/postgres:14-vectorchord0.4.3` container runs stock defaults (`shared_buffers = 128MB`), underutilizing available host memory and NVMe I/O capabilities.
3. **ZFS Recordsize Mismatch for Thumbnails:** The `bulk18/immich-data` dataset uses `recordsize=1M` (optimized for large original photo/video files), creating write amplification and high metadata overhead for thousands of small (<100KB) thumbnail files.
4. **Valkey Persistence Overhead:** The job queue container persists to disk by default, introducing disk sync overhead for transient worker state.

---

## 🛠️ Step-by-Step Optimization Roadmap

```mermaid
graph TD
    subgraph Pre-Work
        A[Check Host GPU: ls /dev/dri] --> B[Create Proxmox Snapshot: pct snapshot 504]
    end

    subgraph Window 1: LXC Config ~15m
        B --> C[Stop CT 504]
        C --> D[Configure /dev/dri Passthrough in 504.conf]
        D --> E[Increase vCPU allocation to 8]
        E --> F[Start CT 504]
        F --> G[Update ML Container in compose with OpenVINO]
    end

    subgraph Window 2: Stack Tuning ~5m
        G --> H[Create postgresql.conf Memory Tuning]
        H --> I[Disable Valkey Disk Persistence]
        I --> J[Pin IMMICH_VERSION in .env]
        J --> K[Restart Database & Redis Containers]
    end

    subgraph No Downtime: UI & Proxy
        K --> L[Tune Worker Concurrency in Web Admin]
        L --> M[Configure Nginx Proxy Caching for Thumbnails]
    end

    classDef stage fill:#2d3748,stroke:#4299e1,stroke-width:2px,color:#fff;
    class A,B,C,D,E,F,G,H,I,J,K,L,M stage;
```

---

## 📋 Execution Playbook

### Phase 1: Pre-Flight Safety & Verification

1. **Verify GPU presence on Dapitan host (`VLAN 1 [Management]`):**
   ```bash
   ssh root@VLAN 1 [Management]
   ls -la /dev/dri
   ```
   *Expected:* `/dev/dri/card0` and `/dev/dri/renderD128` present.

2. **Create Proxmox container snapshot:**
   ```bash
   pct snapshot 504 pre-perf-tuning-20260821 --description "Before performance tuning 2026-08-21"
   pct listsnapshot 504
   ```

---

### Phase 2: Window 1 — LXC & Hardware Acceleration (~15 min)

1. **Stop container:**
   ```bash
   pct stop 504
   ```

2. **Add GPU Passthrough & Increase Cores in `/etc/pve/lxc/504.conf`:**
   ```text
   cores: 8
   lxc.cgroup2.devices.allow: c 226:0 rwm
   lxc.cgroup2.devices.allow: c 226:128 rwm
   lxc.mount.entry: /dev/dri/card0 dev/dri/card0 none bind,optional,create=file
   lxc.mount.entry: /dev/dri/renderD128 dev/dri/renderD128 none bind,optional,create=file
   ```

3. **Start container:**
   ```bash
   pct start 504
   ```

4. **Update `immich-machine-learning` in `/opt/immich/docker-compose.yml`:**
   ```yaml
     immich-machine-learning:
       container_name: immich_machine_learning
       image: ghcr.io/immich-app/immich-machine-learning:${IMMICH_VERSION:-release}
       security_opt:
         - apparmor:unconfined
       devices:
         - /dev/dri:/dev/dri
       volumes:
         - model-cache:/cache
       environment:
         MACHINE_LEARNING_DEVICE_TYPE: openvino
       env_file:
         - .env
       restart: always
   ```

5. **Restart ML service:**
   ```bash
   pct exec 504 -- bash -c "cd /opt/immich && docker compose up -d immich-machine-learning"
   ```

---

### Phase 3: Window 2 — PostgreSQL & Redis Stack Optimization (~5 min)

1. **Create optimized PostgreSQL configuration inside CT 504 (`/opt/immich/postgres-conf/postgresql.conf`):**
   ```ini
   # Memory Configuration (Tuned for 8GB LXC allocation)
   shared_buffers = 2GB
   effective_cache_size = 6GB
   work_mem = 32MB
   maintenance_work_mem = 256MB

   # Write Ahead Logging
   wal_buffers = 32MB
   checkpoint_completion_target = 0.9
   max_wal_size = 1GB

   # Parallel Query Execution
   max_worker_processes = 8
   max_parallel_workers_per_gather = 2
   max_parallel_workers = 4

   # NVMe Storage Optimization (vm-fast pool)
   random_page_cost = 1.1
   effective_io_concurrency = 200
   log_min_duration_statement = 1000
   ```

2. **Update `database` and `redis` services in `/opt/immich/docker-compose.yml`:**
   ```yaml
     redis:
       container_name: immich_redis
       image: docker.io/valkey/valkey:9@sha256:fb8d272e529ea567b9bf1302245796f21a2672b8368ca3fcb938ac334e613c8f
       security_opt:
         - apparmor:unconfined
       command: valkey-server --save "" --appendonly no
       healthcheck:
         test: redis-cli ping || exit 1
       restart: always

     database:
       container_name: immich_postgres
       image: ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0@sha256:bcf63357191b76a916ae5eb93464d65c07511da41e3bf7a8416db519b40b1c23
       security_opt:
         - apparmor:unconfined
       environment:
         POSTGRES_PASSWORD: ${DB_PASSWORD}
         POSTGRES_USER: ${DB_USERNAME}
         POSTGRES_DB: ${DB_DATABASE_NAME}
         POSTGRES_INITDB_ARGS: '--data-checksums'
       volumes:
         - ${DB_DATA_LOCATION}:/var/lib/postgresql/data
         - ./postgres-conf/postgresql.conf:/etc/postgresql/postgresql.conf
       command: postgres -c config_file=/etc/postgresql/postgresql.conf
       shm_size: 128mb
       restart: always
   ```

3. **Pin version in `/opt/immich/.env`:**
   ```env
   IMMICH_VERSION=v3.1.0
   ```

4. **Apply changes:**
   ```bash
   pct exec 504 -- bash -c "cd /opt/immich && docker compose up -d database redis"
   ```

---

### Phase 4: Online & Ingress Adjustments (Zero Downtime)

1. **Immich Web UI Worker Concurrency:**
   Navigate to **Admin Settings → Jobs** and adjust concurrency:
   - **Thumbnail Generation:** `10`
   - **Metadata Extraction:** `10`
   - **Smart Search:** `3`
   - **Face Detection:** `3`
   - **Video Conversion:** `2`

2. **NPM Reverse Proxy Caching (Cebu CT 105):**
   In Proxy Host 9 (`immich.homelab-admin.me`), add to the **Advanced** tab:
   ```nginx
   proxy_cache_valid 200 7d;

   location ~* \.(jpg|jpeg|webp|png|gif)$ {
       proxy_pass http://VLAN 110 (Services):2283;
       proxy_cache_valid 200 7d;
       add_header X-Cache-Status $upstream_cache_status;
   }
   ```

---

### Phase 5: Optional Window 3 — Dedicated Thumbnail ZFS Dataset

> [!NOTE]
> Execute only after confirming cluster stability for 24+ hours.

1. **Create fast thumbnail dataset on Dapitan:**
   ```bash
   zfs create -o recordsize=128K -o compression=lz4 -o mountpoint=/mnt/bindmounts/immich-thumbs bulk18/immich-thumbs
   ```
2. **Stop Immich & rsync thumbnail cache:**
   ```bash
   pct exec 504 -- bash -c "cd /opt/immich && docker compose down"
   rsync -av --progress /mnt/bindmounts/immich-data/thumbs/ /mnt/bindmounts/immich-thumbs/
   ```
3. **Mount dataset to CT 504:**
   ```bash
   pct set 504 -mp1 /mnt/bindmounts/immich-thumbs,mp=/mnt/immich-thumbs
   ```
4. **Update `immich-server` volume mapping:**
   ```yaml
       volumes:
         - ${UPLOAD_LOCATION}:/usr/src/app/upload
         - /mnt/immich-thumbs:/usr/src/app/upload/thumbs
         - /etc/localtime:/etc/localtime:ro
         - /mnt/immich-nas:/mnt/immich-nas
   ```
5. **Start stack:**
   ```bash
   pct exec 504 -- bash -c "cd /opt/immich && docker compose up -d"
   ```

---

## 🔄 Rollback Procedures

| Component | Failure Condition | Rollback Command |
|---|---|---|
| **Full Container** | Kernel panic / complete boot failure | `pct rollback 504 pre-perf-tuning-20260821 && pct start 504` |
| **GPU Passthrough** | LXC fail to start with device error | Remove `/dev/dri` lines from `/etc/pve/lxc/504.conf`, `pct reboot 504` |
| **PostgreSQL** | Database crash on startup | Remove `command:` and config mount from `docker-compose.yml`, `docker compose up -d database` |
| **Valkey (Redis)** | Queue connection error | Remove `command:` line from `redis` service, `docker compose up -d redis` |
| **Thumbnail Dataset** | Images fail to render | Revert compose volume mount, `pct set 504 --delete mp1`, restart container |

---

## 📚 References
- [Immich Hardware Transcoding & OpenVINO Docs](https://immich.app/docs/features/hardware-transcoding)
- [PostgreSQL 14 Performance Tuning Guide](https://wiki.postgresql.org/wiki/Tuning_Your_PostgreSQL_Server)
- [Dapitan Immich Server Setup (2026-07-24)](file:////opt/homelab-infrastructure/06-Guides/Dapitan-Immich-Server-Setup-2026-07-24.md)
