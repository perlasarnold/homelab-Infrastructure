# 🖼️ Dapitan Immich Upgrade & Maintenance Guide

- **Date:** August 16, 2026
- **Objective:** Resolve Immich update failure following base OS package updates (`apt-get upgrade`), execute Docker Compose container upgrade to Immich `v3.1.0`, verify service health, and establish standard maintenance procedures for CT 504 on host `Dapitan`.
- **Status:** Completed / Active
- **Access Endpoints:**
  - Container IP: `http://VLAN 110 (Services):2283`
  - Ingress Reverse Proxy: `https://immich.homelab-admin.me/`

---

## 🔍 Problem Statement & Investigation

### Symptom
Running `apt-get update && apt-get upgrade` inside the host or container did not upgrade the Immich photo management software.

### Root Cause
Immich is deployed as a multi-container Docker Compose application located at `/opt/immich/` inside LXC container 504 (`immich-dapitan`), rather than an Ubuntu APT system package.
- `apt-get` only upgrades underlying Ubuntu distribution packages (e.g. systemd, OpenSSH, libc).
- Immich application services (`immich_server`, `immich_machine_learning`, `immich_postgres`, `immich_redis`) are container images managed via `ghcr.io/immich-app/*` and `valkey/valkey` Docker tags.

---

## 🛠️ Steps Taken & Rationale

### Step 1: Pre-Upgrade Verification
- Connected to Proxmox host Dapitan (`VLAN 1 [Management]`) and inspected CT 504 `/opt/immich/docker-compose.yml` and `.env`.
- Verified `IMMICH_VERSION=RELEASE` in `.env`, configured to pull the latest production release from GitHub Container Registry.
- Identified current running version: **v3.0.3**.

### Step 2: Image Pull & Staging
Executed Docker image pull inside `/opt/immich` to stage the updated layers without disrupting active users:
```bash
pct exec 504 -- sh -c 'cd /opt/immich && docker compose pull'
```
*Rationale:* Pre-pulling images minimizes service interruption time during container recreation.

### Step 3: Container Recreation & Database Migration
Triggered container recreation with the new release images:
```bash
pct exec 504 -- sh -c 'cd /opt/immich && docker compose up -d'
```
*Rationale:* Docker Compose gracefully restarts `immich_redis`, `immich_postgres`, `immich_machine_learning`, and `immich_server`, triggering automated internal database schema migrations on startup.

### Step 4: Storage Cleanup
Pruned obsolete container layers to maintain NVMe root filesystem efficiency on `vm-fast`:
```bash
pct exec 504 -- docker image prune -f
```
*Outcome:* Reclaimed **1.017 GB** of disk space.

---

## 📊 Outcome & Verification

### Service Health
All four stack containers are running and healthy:

| Container | Image Tag | Status | Port |
| :--- | :--- | :--- | :--- |
| `immich_server` | `ghcr.io/immich-app/immich-server:RELEASE` (`v3.1.0`) | `Up (healthy)` | `2283/tcp` |
| `immich_machine_learning` | `ghcr.io/immich-app/immich-machine-learning:RELEASE` | `Up (healthy)` | Internal |
| `immich_postgres` | `ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0` | `Up (healthy)` | `5432/tcp` |
| `immich_redis` | `docker.io/valkey/valkey:9` | `Up (healthy)` | `6379/tcp` |

### API Health & Version Verification
- `curl http://VLAN 110 (Services):2283/api/server/version` ➡️ `{"major":3,"minor":1,"patch":0,"prerelease":null}`
- `curl http://VLAN 110 (Services):2283/api/server/ping` ➡️ `{"res":"pong"}`

---

## 📖 Standard Upgrade Procedure for Future Releases

To perform future upgrades on Dapitan CT 504:

```bash
# 1. Access Dapitan CT 504
ssh root@VLAN 1 [Management]
pct enter 504

# 2. Navigate to Immich stack directory
cd /opt/immich

# 3. Pull latest images and restart stack
docker compose pull
docker compose up -d

# 4. Prune unused images
docker image prune -f

# 5. Verify logs
docker compose logs -f --tail=50
```

---

## 🔗 References
- [Immich Official Upgrade Guide](https://docs.immich.app/install/upgrading/)
- [Dapitan Immich Server Setup Guide (2026-07-24)](file:////opt/homelab-infrastructure/06-Guides/Dapitan-Immich-Server-Setup-2026-07-24.md)
