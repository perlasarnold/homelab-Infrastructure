# 🌐 Bulakan Proxmox Homepage Deployment Guide

- **Date:** August 13, 2026
- **Objective:** Provision a dedicated Homepage (`gethomepage.dev`) dashboard running in a Debian 12 LXC container (**CT 116**) on the Bulakan Proxmox VE node (`192.168.10.25`), accessible externally via Cloudflare Tunnel at `https://home.homelab-admin.me`.
- **Maintainer:** Perlas

---

## 🛡️ Production Environment Safety & Non-Disruption Guarantee

- **Zero Reboot Policy:** This deployment creates an isolated unprivileged LXC container (`CT 116`) and requires **NO system reboots, NO service restarts, and NO disruption** to any existing host nodes (`Bulakan`, `Cebu`, `Dapitan`), VMs, or running containers.
- **Rollback Safety:** If unprovisioned or stopped, destroying `CT 116` removes the service cleanly without impacting any underlying storage or network interfaces.

---

## 🖥️ System Architecture & Context

Homepage is deployed on the primary Proxmox hypervisor node (`Bulakan`) inside `CT 116` to serve as the landing page and monitoring dashboard for `home.homelab-admin.me`.

| Parameter | Specification | Rationale |
| :--- | :--- | :--- |
| **Host Node** | `Bulakan` (`192.168.10.25`) | Primary hypervisor node in the cluster. |
| **Container ID** | **CT 116** | Designated VMID allocation on Bulakan. |
| **Instance Type** | Unprivileged LXC + Nesting | Lightweight resource footprint (~256 MB RAM) with Docker Compose support. |
| **Operating System** | Debian 12 (Bookworm) | Stable base for Docker workloads. |
| **Public FQDN** | `https://home.homelab-admin.me` | Publicly resolvable HTTPS endpoint via Cloudflare Tunnel. |
| **Ingress Router** | Cloudflare Tunnel (`cloudflared-bulakan` CT 304 / `192.168.120.6`) | Zero open inbound ports required on edge firewall. |
| **Network IP** | `192.168.110.50` (VLAN 110 Services) | Static IP allocation on the Services subnet. |
| **Port** | `3000` | Homepage HTTP web port. |

---

## 🛠️ Step 1: Proxmox LXC Container Provisioning (CT 116)

Execute on **Bulakan PVE** (`192.168.10.25:8006`) via PVE Web Shell or SSH:

```bash
# Provision LXC Container ID 116 (Zero disruption to host)
pct create 116 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  --hostname homepage-bulakan \
  --cores 2 \
  --memory 1024 \
  --swap 512 \
  --features nesting=1,keyctl=1 \
  --net0 name=eth0,bridge=vmbr0,tag=110,ip=192.168.110.50/24,gw=192.168.110.1 \
  --storage local-lld \
  --rootfs local-lld:8 \
  --unprivileged 1 \
  --start 1
```

---

## 🐋 Step 2: Install Docker & Docker Compose inside CT 116

Attach to `CT 116`:
```bash
pct enter 116
```

Inside `CT 116`:
```bash
# Update repositories and install prerequisites
apt-get update && apt-get install -y curl ca-certificates gnupg lsb-release

# Add Docker Official GPG Key & Repository
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine & Compose
apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Enable Docker service
systemctl enable --now docker
```

---

## ⚙️ Step 3: Deploy Homepage via Docker Compose

```bash
mkdir -p /opt/homepage/config
cd /opt/homepage
```

### 1. Save `docker-compose.yml`
```yaml
name: homepage

services:
  homepage:
    image: ghcr.io/gethomepage/homepage:latest
    container_name: homepage
    ports:
      - "3000:3000"
    volumes:
      - ./config:/app/config
      - /var/run/docker.sock:/var/run/docker.sock:ro
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Asia/Manila
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:3000/ || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3
```

### 2. Launch Service
```bash
docker compose up -d
```

---

## 🌐 Step 4: Cloudflare Tunnel Ingress Setup (`homelab-admin.me`)

To route external requests to Homepage and your services via Cloudflare Tunnel (`cloudflared-bulakan`):

### 1. Primary Dashboard Endpoint
- **Public Hostname:** `home.homelab-admin.me`
- **Service Type:** `HTTP`
- **Internal Target:** `192.168.110.50:3000`

### 2. Configured Subdomain Service Mappings
Homepage will display and link to all subdomains configured in your Cloudflare DNS zone:

| Subdomain FQDN | Service Target | Purpose |
| :--- | :--- | :--- |
| `https://home.homelab-admin.me` | Homepage (CT 116) | Centralized Homelab Dashboard |
| `https://auth.homelab-admin.me` | Authentik SSO | Central Identity Provider & Authentication |
| `https://guacamole.homelab-admin.me` | Apache Guacamole | HTML5 Remote Desktop (Mint VM) |
| `https://immich.homelab-admin.me` | Immich Server | Self-hosted Photo & Video Backup |
| `https://plex.homelab-admin.me` | Plex Media Server | Primary Media Streaming |
| `https://plex-unraid.homelab-admin.me` | Plex (Unraid) | Unraid Media Server |
| `https://jellyfin.homelab-admin.me` | Jellyfin Primary | Main Jellyfin Media Server |
| `https://jellyfincb.homelab-admin.me` | Jellyfin Cebu | Cebu Node Jellyfin Server |
| `https://jellyfinpx.homelab-admin.me` | Jellyfin Proxmox | Proxmox Jellyfin Server |
| `https://portainer.homelab-admin.me` | Portainer | Docker Container Management |
| `https://casa.homelab-admin.me` | CasaOS | Smart Home & Application Hub |
| `https://synology.homelab-admin.me` | Synology DSM | DiskStation Manager Admin Interface |
| `https://synphotos.homelab-admin.me` | Synology Photos | Photo Library Management |
| `https://synfiles.homelab-admin.me` | Synology Files | File Station Cloud Web |
| `https://syndrive.homelab-admin.me` | Synology Drive | Personal Cloud Sync |
| `https://drive.homelab-admin.me` | Nextcloud / Drive | Storage Drive |
| `https://obsidian.homelab-admin.me` | Obsidian Sync | Knowledge Base Vault |
| `https://audiobookbay.homelab-admin.me` | Audiobookshelf | Audiobooks & E-books |
| `https://heimdall.homelab-admin.me` | Heimdall | Secondary Dashboard Launcher |
| `https://homelab-admin.me` | GitHub Pages | Personal Website & Portfolio |

---

## 📊 Outcome & Verification

- **Internal Access:** `http://192.168.110.50:3000`
- **External Access:** `https://home.homelab-admin.me`
- **Service Impact:** **0 host reboots, 0 container restarts, 0 service outages.**

---

## 🔗 References

- [Homepage Official Documentation](https://gethomepage.dev/)
- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
- [Class C Subnet & IP Allocation Schema Recommendation](../04-Network/Class-C-Subnet-Schema-Recommendation.md)
