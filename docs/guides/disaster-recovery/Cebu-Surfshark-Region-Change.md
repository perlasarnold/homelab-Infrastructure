# 🦈 Surfshark VPN Region Change Guide (WireGuard & Gluetun)

- **Date:** Updated August 25, 2026
- **Objective:** Change the connected country/region of the Surfshark VPN tunnel on the Cebu Proxmox host (`arr-stack-cebu` / CT 417).
- **Maintainer:** Homelab Admin

---

## 🌍 Why Change Regions?
If public or private trackers (such as TorrentLeech, 1337x, or TorrentGalaxy) or indexers are blocking automated searches with "Forbidden", Cloudflare captchas, or TCP connection resets, switching your VPN IP to a different country/server endpoint bypasses IP-level blocks.

---

## 🛠️ Method 1: Native WireGuard on LXC (Current Production on CT 417)

On **`arr-stack-cebu` (CT 417)**, WireGuard runs as a native systemd service (`wg-quick@wg0.service`) with built-in iptables killswitch rules.

### 1. Update the WireGuard Configuration
SSH into your Proxmox host and edit `/etc/wireguard/wg0.conf` inside CT 417:

```bash
pct exec 417 -- cp /etc/wireguard/wg0.conf /etc/wireguard/wg0.conf.bak
pct exec 417 -- nano /etc/wireguard/wg0.conf
```

Under the `[Peer]` section, update the `Endpoint` and `PublicKey` for your target region:

```ini
[Interface]
Address = 10.14.0.2/16
PrivateKey = <YOUR_WIREGUARD_PRIVATE_KEY>
DNS = 162.252.172.57, 149.154.159.92

# Routing & Kill-switch
PostUp = ip route add 192.168.0.0/16 via 192.168.110.1 dev eth0 || true
PostUp = ip route add 100.64.0.0/10 via 192.168.110.1 dev eth0 || true
PostUp = iptables -I OUTPUT 1 -o eth0 -d 192.168.0.0/16 -j ACCEPT
PostUp = iptables -I OUTPUT 2 -o eth0 -d 100.64.0.0/10 -j ACCEPT
PostUp = iptables -I OUTPUT 3 -o eth0 -p udp --dport 51820 -j ACCEPT
PostUp = iptables -I OUTPUT 4 -o wg0 -j ACCEPT
PostUp = iptables -A OUTPUT -o eth0 -j REJECT

PreDown = iptables -D OUTPUT -o eth0 -j REJECT || true
PreDown = iptables -D OUTPUT 1 || true
PreDown = iptables -D OUTPUT 1 || true
PreDown = iptables -D OUTPUT 1 || true
PreDown = iptables -D OUTPUT 1 || true
PreDown = ip route del 192.168.0.0/16 via 192.168.110.1 dev eth0 || true
PreDown = ip route del 100.64.0.0/10 via 192.168.110.1 dev eth0 || true

[Peer]
PublicKey = <SURFSHARK_SERVER_PUBLIC_KEY>
AllowedIPs = 0.0.0.0/0
Endpoint = <SURFSHARK_ENDPOINT_HOSTNAME_OR_IP>:51820
PersistentKeepalive = 25
```

### 2. Restart the WireGuard Service
```bash
pct exec 417 -- bash -c "wg-quick down wg0 2>/dev/null || ip link del wg0 2>/dev/null || true; systemctl start wg-quick@wg0"
```

### 3. Verify Public IP & Reachability
```bash
pct exec 417 -- wg show
pct exec 417 -- curl -s https://ipinfo.io
```

---

## 🛠️ Method 2: Docker Compose (Gluetun Container)

If running Gluetun inside Docker Compose (`/root/arr-stack/docker-compose.yml`):

```yaml
  gluetun:
    image: qmcgaw/gluetun
    container_name: gluetun
    environment:
      - VPN_SERVICE_PROVIDER=custom
      - VPN_TYPE=wireguard
      - WIREGUARD_PRIVATE_KEY=<YOUR_KEY>
      - WIREGUARD_ADDRESSES=10.14.0.2/16
      - WIREGUARD_PUBLIC_KEY=<SERVER_PUBLIC_KEY>
      - WIREGUARD_ENDPOINT_IP=<ENDPOINT_IP>
      - WIREGUARD_ENDPOINT_PORT=51820
```

Apply the changes:
```bash
pct exec 417 -- bash -c 'cd /root/arr-stack && docker compose up -d'
```

---

## ✅ Outcome
The WireGuard VPN tunnel routes all indexer, torrent, and tracker traffic through the specified country, bypassing geographic blocks and Cloudflare IP bans.
