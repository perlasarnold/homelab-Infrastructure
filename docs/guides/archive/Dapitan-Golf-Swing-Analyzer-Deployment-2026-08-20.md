# ⛳ Golf Swing Analyzer Container Deployment & Immich Integration Guide (Dapitan Node)

- **Date:** August 20, 2026
- **Objective:** Provision a persistent, web-enabled containerized instance of **`greggjuri/golf-swing-analyzer`** on Proxmox node **Dapitan** (`VLAN 1 [Management]`) with mass storage on ZFS pool `bulk18`, direct **Immich media library read-only mounts**, HTML5 noVNC streaming interface, HTTPS SSL reverse proxying via Nginx Proxy Manager (`VLAN 120 (DMZ)`), and Single Sign-On authentication via Authentik (`https://auth.homelab-admin.me`).
- **Outcome:** Successfully containerized with multi-stage Docker build, persistent ZFS dataset mounts (`bulk18/golf-analyzer-data`), read-only Immich mobile video dataset mounts (`/app/data/immich:ro`), zero-install HTML5 browser access via noVNC (port `8086`), and zero-trust SSO protection at `https://golf.homelab-admin.me`.

---

## 🏗️ Architecture & Component Inventory

| Component | Node / Location | IP / Port | Function & Configuration |
| :--- | :--- | :--- | :--- |
| **Proxmox Node** | `Dapitan` | `VLAN 1 [Management]` | Proxmox VE host running ZFS pool `bulk18` & `vm-fast` |
| **LXC Guest (CT 513)** | `golf-analyzer-dapitan` | `VLAN 110 (Services)` | Privileged Ubuntu 22.04 LXC (`nesting=1,keyctl=1`, 4 vCPU, 4GB RAM) |
| **ZFS Mass Storage** | `bulk18/golf-analyzer-data` | `/mnt/bindmounts/golf-analyzer-data` | Host ZFS dataset (`recordsize=128k`, `zstd`) mounted into CT 513 |
| **Immich Media Mount** | `bulk18/immich-data` | `/mnt/bindmounts/immich-data` | Read-only host ZFS dataset mounted to `/app/data/immich:ro` |
| **GUI & Processing Engine** | CT 513 Docker | Port `8086` | Python 3.10+, OpenCV, MediaPipe, PyQt5 application |
| **Display Server & Web Streamer** | CT 513 Docker | Port `8086` | Xvfb (`:99`), fluxbox WM, x11vnc (`:5900`), websockify / noVNC |
| **Pi-hole Local DNS** | Bulakan (`CT 301`) | `VLAN 1 [Primary DNS]` | Maps `golf.homelab-admin.me` to NPM (`VLAN 120 (DMZ)`) |
| **Nginx Proxy Manager** | Cebu (`CT 105`) | `VLAN 120 (DMZ)` | Reverse proxy & SSL termination (`*.homelab-admin.me`) |
| **Authentik IdP** | Cebu (`CT 103`) | `VLAN 110 (Services):9000` | Forward Auth Proxy Outpost for Single Sign-On |

---

## 🛠️ Step-by-Step Implementation

### 1. Host ZFS Storage & Immich Read-Only Mount
- Created ZFS dataset `bulk18/golf-analyzer-data` on host Dapitan and attached Immich bind mount:
  ```bash
  zfs create -o recordsize=128k -o compression=zstd bulk18/golf-analyzer-data
  mkdir -p /mnt/bindmounts/golf-analyzer-data/input /mnt/bindmounts/golf-analyzer-data/output /mnt/bindmounts/golf-analyzer-data/drawings
  chmod -R 777 /mnt/bindmounts/golf-analyzer-data

  # Bind mount Immich ZFS dataset read-only to LXC CT 513
  pct set 513 -mp1 /mnt/bindmounts/immich-data,mp=/mnt/bulk18/immich-data,ro=1
  ```

### 2. Containerized Application Architecture (`/opt/golf-swing-analyzer`)
- `docker-compose.yml`:
  ```yaml
  version: '3.8'

  services:
    golf-swing-analyzer:
      build:
        context: .
        dockerfile: docker/Dockerfile
      image: golf-swing-analyzer:latest
      container_name: golf-swing-analyzer
      restart: unless-stopped
      ports:
        - "8086:8086"
      environment:
        - DISPLAY=:99
        - RESOLUTION=1920x1080x24
      volumes:
        - /mnt/bulk18/golf-analyzer-data/input:/app/data/input
        - /mnt/bulk18/golf-analyzer-data/output:/app/data/output
        - /mnt/bulk18/golf-analyzer-data/drawings:/app/data/drawings
        - /mnt/bulk18/immich-data:/app/data/immich:ro
      security_opt:
        - apparmor:unconfined
  ```

---

## ✅ Verification & Outcome

- **Immich Integration:** In `golf-swing-analyzer`, clicking **File $\rightarrow$ Open Video** (`Ctrl+O`) allows opening mobile videos directly from `/app/data/immich/library/` or `/app/data/immich/upload/`.
- **Read-Only Security:** Attempting to modify `/app/data/immich` inside the container returns `Read-only file system`, preserving original Immich assets.
- **Public Ingress:** `https://golf.homelab-admin.me` serves the zero-install HTML5 noVNC canvas.

---

## 📚 References
- Project Repository: [greggjuri/golf-swing-analyzer](https://github.com/greggjuri/golf-swing-analyzer)
- Automated Deployment Script: [deploy-golf-analyzer-dapitan.sh](file:////opt/homelab-infrastructure/scripts/deploy-golf-analyzer-dapitan.sh)
- Immich Architecture: [Dapitan Immich Setup](file:////opt/homelab-infrastructure/06-Guides/Dapitan-Immich-Server-Setup-2026-07-24.md)
