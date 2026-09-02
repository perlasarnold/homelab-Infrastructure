# 🚀 Sonarr / Prowlarr Indexer Timeout, TorrentLeech & Auto-Failover VPN Guide

- **Date:** 2026-08-25
- **Objective:** Troubleshoot Sonarr indexer downtime ("All indexers are unavailable due to failures"), resolve dual-stack IPv6 socket hangs, integrate private tracker TorrentLeech, and implement an automatic zero-touch VPN health failover and region-switching utility.
- **Maintainer:** Homelab Admin

---

## 🔍 Problem Statement
1. **Sonarr Health Warnings:** Sonarr reported critical health check failures:
   - *All rss-capable indexers are temporarily unavailable due to recent indexer errors*
   - *All search-capable indexers are temporarily unavailable due to recent indexer errors*
   - *All indexers are unavailable due to failures for more than 6 hours*
2. **Indexer Addition Timeouts:** Attempts to add private tracker **TorrentLeech** timed out during connection validation in Prowlarr.

---

## 🔬 Root Cause Investigation
1. **VPN IP Dropping Connections:** Outbound traffic from `arr-stack-cebu` (CT 417) was routed through Surfshark endpoint `89.187.187.86:51820` (Los Angeles Datacamp / CDN77). Cloudflare and TorrentLeech were resetting TCP/SSL connections (`Connection reset by peer`) from this specific VPN IP address.
2. **Dual-Stack IPv6 Socket Timeouts:** Dual-stack DNS lookups inside Docker containers returned AAAA IPv6 records. Because the WireGuard VPN tunnel only routes IPv4 (`10.14.0.2/16`), .NET `SocketsHttpHandler` connections in Sonarr/Prowlarr hung waiting for IPv6 timeouts before falling back to IPv4.
3. **WireGuard MTU / TCP MSS Fragmentation:** Large multi-kilobyte JSON browse responses from TorrentLeech were fragmented and dropped over the WireGuard tunnel (`MTU 1420`) because TCP MSS clamping was not active on the tunnel.

---

## 🛠️ Resolution Steps

### 1. Added `.NET` IPv6 Disablement to `docker-compose.yml`
Added `DOTNET_SYSTEM_NET_DISABLEIPV6=1` to the environment of all Servarr containers (`prowlarr`, `sonarr`, `radarr`, `jackett`) to force .NET to use fast IPv4 sockets exclusively.

### 2. Configured TCP MSS Clamping in WireGuard
Added automatic MTU negotiation to `/etc/wireguard/wg0.conf`:
```ini
PostUp = iptables -t mangle -A POSTROUTING -p tcp --tcp-flags SYN,RST SYN -o wg0 -j TCPMSS --clamp-mss-to-pmtu
PreDown = iptables -t mangle -D POSTROUTING -p tcp --tcp-flags SYN,RST SYN -o wg0 -j TCPMSS --clamp-mss-to-pmtu || true
```

### 3. Deployed `switch-vpn` CLI Utility
Installed `/usr/bin/switch-vpn` to quickly toggle or check WireGuard region profiles:
- Predefined region profiles stored in `/etc/wireguard/regions/`:
  - `br-sao.conf` (São Paulo, Brazil)
  - `us-sfo.conf` (San Francisco, USA)
  - `us-lax.conf` (Los Angeles, USA)
- Commands:
  - `switch-vpn status`: Shows active tunnel, handshake, and public egress IP.
  - `switch-vpn <region>`: Atomically swaps config and restarts WireGuard (e.g. `switch-vpn br`).
  - `switch-vpn next`: Cycles to the next available region profile.

### 4. Enabled Zero-Touch Auto-Failover Daemon (`vpn-failover.timer`)
Configured a lightweight systemd timer that runs `/usr/bin/vpn-failover.sh` every 5 minutes:
- Probes external tracker and DNS connectivity.
- If 2 consecutive failures occur (e.g. current VPN IP blocked by Cloudflare/tracker), it automatically triggers `switch-vpn next` to rotate to the next clean VPN region without manual intervention.

---

## ✅ Outcome & Verification
- **Sonarr Health:** **0 warnings, 0 errors** (all health checks cleared).
- **TorrentLeech Status:** **`HTTP 200 OK`** in Prowlarr and Sonarr.
- **Failover Daemon:** Active and scheduled (`vpn-failover.timer`).
- **Current Active Region:** `br-sao` (`146.70.163.206` / São Paulo, Brazil).

---

## 📑 References
- [Cebu Surfshark Region Change Guide](./Cebu-Surfshark-Region-Change.md)
- [Class C Subnet Schema](../../architecture/class-c-subnet-schema.md)
- [Master Arr Stack Setup Guide](../media-automation/Master-Arr-Stack-Sonarr-NPM-WireGuard-Setup-Guide-2026-08-22.md)
