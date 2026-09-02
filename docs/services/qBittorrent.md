# 📥 qBittorrent Setup & Operations

High-performance, leak-proof BitTorrent client integrated with the Servarr automation stack and routed exclusively through a Gluetun WireGuard VPN sidecar.  
**Last Updated:** 2026-08-31

---

## 🛠️ Deployment Details

- **Host:** Proxmox VE — **Cebu** (CT 417 `arr-stack-cebu`)
- **Compose Stack:** `/root/qbit-stack/docker-compose.yml`
- **Network Mode:** `service:gluetun` (Docker namespace isolation)
- **VPN Sidecar:** `qmcgaw/gluetun:latest` (Surfshark WireGuard)
- **Internal URL:** `http://gluetun:8080` (Internal Docker network `downloads_net`)
- **WebUI URL:** `http://192.168.110.42:8080` → Reverse Proxied at [https://torrent.perlasarnold.me](https://torrent.perlasarnold.me)
- **Storage Mount:** `/mnt/seagate/Downloads` (`//192.168.1.12/Seagate/Downloads`)
- **Health & Stall Monitor:** `qbit-health.timer` (systemd timer every 5 min)

---

## 📋 Architecture & Network Topology

```
┌────────────────────────────────────────────────────────┐
│               Proxmox CT 417 (arr-stack-cebu)          │
│                                                        │
│   ┌────────────────────────────────────────────────┐   │
│   │ /root/qbit-stack/                              │   │
│   │                                                │   │
│   │   [Gluetun VPN Sidecar] ──► Surfshark Tunnel   │   │
│   │           ▲                                    │   │
│   │           │ (network_mode: service:gluetun)    │   │
│   │   [qBittorrent WebUI:8080 / Peer:6881]         │   │
│   └───────────────────▲────────────────────────────┘   │
│                       │ downloads_net (Docker Bridge)  │
│   ┌───────────────────┴────────────────────────────┐   │
│   │ /root/arr-stack/                               │   │
│   │   [Sonarr] ──► http://gluetun:8080             │   │
│   │   [Radarr] ──► http://gluetun:8080             │   │
│   │   [Prowlarr / Bazarr / Readarr]                │   │
│   └────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────┘
```

---

## 🔒 Security & VPN Leak Prevention

1. **Namespace Isolation:** qBittorrent does not possess its own network interface. It shares Gluetun's network stack (`tun0`), ensuring that if the VPN goes down, all traffic is instantly blocked (built-in container killswitch).
2. **Subnet Whitelist:** Internal LAN and Docker bridge subnets (`192.168.0.0/16`, `172.16.0.0/12`, `100.64.0.0/10`) are allowed through Gluetun's firewall exceptions (`FIREWALL_OUTBOUND_SUBNETS`) for direct Arr-stack API communication.
3. **No Port Forwarding:** Inbound torrent peer connections are managed via standard NAT / DHT over the WireGuard tunnel.

---

## 🔄 Automated Failover (`qbit-health.timer`)

A custom health monitoring daemon checks active downloads every 5 minutes:
- **Location:** `/usr/bin/qbit-health.sh`
- **Timer:** `qbit-health.timer`
- **Behavior:** If active torrents remain stalled at 0 B/s for 15+ minutes (3 consecutive checks), it automatically restarts Gluetun to cycle to the next healthy Surfshark VPN endpoint.

---

## 📜 Historical Note & Migration
* **Transmission BitTorrent (Decommissioned):** Transmission was deprecated and fully decommissioned on 2026-08-31 due to WireGuard killswitch routing conflicts on the shared LXC bridge network. Configuration is archived at `/root/arr-stack/config/transmission.bak`.
* **Migration Runbook:** [`Transmission-to-qBittorrent-Gluetun-Migration-2026-08-31.md`](../guides/media-automation/Transmission-to-qBittorrent-Gluetun-Migration-2026-08-31.md)
