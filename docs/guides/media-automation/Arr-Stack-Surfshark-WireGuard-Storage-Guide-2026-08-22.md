# 🛡️ Arr Stack Surfshark WireGuard & NAS Storage Configuration Guide

- **Date:** August 22, 2026
- **Objective:** Configure Gluetun with dedicated Surfshark WireGuard tunnel credentials, enforce strict fail-closed killswitch routing for Transmission, and map shared NAS storage (`\\pnas\Seagate\Share\Downloads` and `\\pnas\Seagate\Share\TV Shows`) to the Cebu Arr Stack (CT 417).
- **Maintainer:** Perlas

---

## 🛠️ Architecture & Configuration Summary

### 1. Storage & Media Path Mappings
The Synology NAS (`//VLAN 1 [MGMT-NAS]/Seagate`) CIFS share is permanently mounted on Proxmox host Cebu and bind-mounted to CT 417:

| Host Mount | Container Mount | Docker Path | Target Share | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| `/mnt/plex1/Share` | `/mnt/seagate` | `/downloads` | `\\pnas\Seagate\Share\Downloads` | Torrent download directory |
| `/mnt/plex1/Share` | `/mnt/seagate` | `/tv` | `\\pnas\Seagate\Share\TV Shows` | Sonarr Root TV Library |
| `/mnt/plex1/Share` | `/mnt/seagate` | `/movies` | `\\pnas\Seagate\Share\Movies` | Radarr Root Movie Library |

- **Sonarr Root Folder:** Registered `/tv` (110+ series indexed with automatic media discovery).
- **Transmission Download Path:** Default completed path `/downloads/complete/tv-sonarr`.

---

### 2. Surfshark WireGuard Tunnel & Killswitch
Gluetun (`qmcgaw/gluetun`) is configured with dedicated WireGuard credentials connecting to Surfshark US (San Francisco):

```yaml
  gluetun:
    image: qmcgaw/gluetun
    container_name: gluetun
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    ports:
      - "9117:9117" # Jackett
      - "9696:9696" # Prowlarr
      - "9091:9091" # Transmission Web UI
      - "51413:51413"
      - "51413:51413/udp"
    environment:
      - VPN_SERVICE_PROVIDER=custom
      - VPN_TYPE=wireguard
      - WIREGUARD_PRIVATE_KEY=<YOUR_WIREGUARD_PRIVATE_KEY>
      - WIREGUARD_ADDRESSES=10.14.0.2/16
      - WIREGUARD_PUBLIC_KEY=<SURFSHARK_SERVER_PUBLIC_KEY>
      - WIREGUARD_ENDPOINT_IP=198.51.100.10
      - WIREGUARD_ENDPOINT_PORT=51820
      - DOT=off
      - DNS_PLAINTEXT_ADDRESS=1.1.1.1
      - FIREWALL_OUTBOUND_SUBNETS=192.168.1.0/24,VLAN 110 (Services)/24,VLAN 120 (DMZ)/24
      - TZ=America/Los_Angeles
    restart: always

  transmission:
    image: lscr.io/linuxserver/transmission:latest
    container_name: transmission
    network_mode: "service:gluetun"
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Los_Angeles
    volumes:
      - ./config/transmission:/config
      - /mnt/seagate/Downloads:/downloads
      - ./data/watch:/watch
    depends_on:
      gluetun:
        condition: service_healthy
    restart: unless-stopped
```

---

## 🔒 Security & Killswitch Verification

1. **Network Namespace Isolation:** `network_mode: "service:gluetun"` ensures Transmission has no independent virtual network interface. It shares Gluetun's network stack directly.
2. **Kernel Firewall Killswitch:** Gluetun's built-in `iptables` drop rule blocks all non-VPN outgoing traffic. If WireGuard drops, internet traffic stops instantly.
3. **Public IP Verification:** 
   ```bash
   docker exec transmission wget -qO- https://ipinfo.io/json
   # IP: 198.51.100.25 (AS60068 Datacamp Limited / Surfshark VPN)
   ```
4. **Sonarr Health Status:** `/api/v3/health` returns `[]` (0 errors, 0 warnings).

---

## 📚 References
- [Gluetun WireGuard Documentation](https://github.com/qdm12/gluetun-wiki/blob/main/setup/providers/surfshark.md)
- [Sonarr Documentation](https://sonarr.tv/)
