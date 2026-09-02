# 🚀 Transmission to Standalone qBittorrent + Gluetun VPN Migration Guide

- **Date:** 2026-08-31
- **Objective:** Migrate download client from Transmission to standalone qBittorrent enclosed in a Gluetun WireGuard VPN sidecar, eliminate routing killswitch hairpin drops, migrate active torrents without re-downloading, and implement automated download health monitoring.
- **Maintainer:** Homelab Admin

---

## 🔍 Problem & Motivation
Transmission previously ran directly alongside the Servarr stack on the same bridge network within LXC 417 (`arr-stack-cebu`).
- **Routing Conflict:** The LXC host-level WireGuard killswitch blocked traffic between containers attempting to reach Transmission via the LXC host IP (`192.168.110.42:9091`).
- **Isolation Need:** Moving qBittorrent into a dedicated stack with its own Gluetun VPN sidecar allows independent lifecycle management and ensures that all download traffic is strictly VPN-isolated while internal Arr stack communication stays on an internal Docker bridge.

---

## 🛠️ Architecture & Deployment

### 1. Standalone Stack: `/root/qbit-stack/docker-compose.yml`
```yaml
services:
  gluetun:
    image: qmcgaw/gluetun:latest
    container_name: gluetun
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    environment:
      - VPN_SERVICE_PROVIDER=surfshark
      - VPN_TYPE=wireguard
      - WIREGUARD_PRIVATE_KEY=<sanitized>
      - WIREGUARD_ADDRESSES=10.14.0.2/16
      - SERVER_COUNTRIES=United States,Brazil
      - SERVER_CITIES=San Francisco,Seattle,Sao Paulo
      - FIREWALL_OUTBOUND_SUBNETS=192.168.0.0/16,172.16.0.0/12,100.64.0.0/10,10.0.0.0/8
      - UPDATER_PERIOD=24h
    ports:
      - "8080:8080"
      - "6881:6881"
      - "6881:6881/udp"
    networks:
      - downloads_net
    restart: unless-stopped

  qbittorrent:
    image: lscr.io/linuxserver/qbittorrent:latest
    container_name: qbittorrent
    network_mode: "service:gluetun"
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Los_Angeles
      - WEBUI_PORT=8080
      - TORRENTING_PORT=6881
    volumes:
      - ./config/qbittorrent:/config
      - /mnt/seagate/Downloads:/downloads
    depends_on:
      gluetun:
        condition: service_healthy
    restart: unless-stopped

networks:
  downloads_net:
    external: true
```

### 2. Internal Docker Network (`downloads_net`)
- Created bridge network `downloads_net` to allow Sonarr and Radarr to communicate directly with `http://gluetun:8080` without traversing host `eth0` or the external network.
- Configured qBittorrent LAN whitelist to bypass authentication for internal RFC1918 / Docker subnets.

### 3. Automated Stall Detection & VPN Failover (`qbit-health.timer`)
- Deployed `/usr/bin/qbit-health.sh` via systemd timer running every 5 minutes.
- Monitors active torrents. If torrents are stalled at 0 B/s for 15+ minutes, it automatically restarts Gluetun to cycle to the next VPN server.

---

## 📊 Verification & Outcome
- **qBittorrent WebUI:** Accessible on port `8080`.
- **Egress IP:** Egressing via Surfshark VPN tunnel (`138.199.58.34`).
- **Torrent Migration:** Active Transmission torrents migrated into qBittorrent without re-download.
- **Servarr Integration:**
  - Sonarr: Connected to qBittorrent (`HTTP 200 SUCCESS`), 0 health errors.
  - Radarr: Connected to qBittorrent (`HTTP 200 SUCCESS`), 0 health errors.
- **Transmission:** Container stopped and removed, configuration safely archived to `/root/arr-stack/config/transmission.bak`.

---

## 📑 References
- [Master Arr Stack Setup Guide](../media-automation/Master-Arr-Stack-Sonarr-NPM-WireGuard-Setup-Guide-2026-08-22.md)
- [Sonarr-Prowlarr TorrentLeech & Auto-Failover Guide](../disaster-recovery/Sonarr-Prowlarr-TorrentLeech-VPN-Troubleshooting-2026-08-25.md)
