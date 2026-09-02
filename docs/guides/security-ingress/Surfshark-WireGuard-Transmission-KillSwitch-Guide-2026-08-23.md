# 🛡️ Surfshark WireGuard VPN & Transmission Kill Switch Guide

> [!WARNING]
> **ARCHIVED / SUPERSEDED (2026-08-31)**  
> Transmission has been superseded and migrated to standalone **qBittorrent** with a dedicated Gluetun WireGuard VPN sidecar.  
> See the active migration runbook: [`Transmission-to-qBittorrent-Gluetun-Migration-2026-08-31.md`](../media-automation/Transmission-to-qBittorrent-Gluetun-Migration-2026-08-31.md)

* **Date:** 2026-08-23
* **Objective:** Establish an isolated, encrypted WireGuard VPN tunnel (`wg0`) for Transmission and the Arr Stack on Proxmox CT 417 (`arr-stack-cebu`), enforcing a strict iptables kill switch to prevent WAN IP leaks while preserving LAN reverse proxy accessibility.
* **Target Container:** Proxmox LXC CT 417 (`192.168.110.42`) on Node Cebu (`192.168.1.26`)
* **VPN Provider:** Surfshark VPN (WireGuard protocol)

---

## 1. Problem Statement & Audit Findings

During audit on 2026-08-23, checking public IP egress inside CT 417 via `curl -s https://ipinfo.io/json` revealed:
- **Egress IP:** `76.170.1.170` (Residential Charter/Spectrum WAN IP)
- **Root Cause:** WireGuard (`wg0`) was not running at the OS level; traffic was directly routing to default gateway `192.168.110.1` on `eth0`.

---

## 2. Architecture & Design Decisions

```
┌────────────────────────────────────────────────────────┐
│               Proxmox CT 417 (arr-stack-cebu)          │
│                                                        │
│   [Transmission BitTorrent]   [Sonarr/Radarr/Readarr] │
│              │                           │             │
│              ▼                           ▼             │
│    ┌──────────────────┐         ┌──────────────────┐   │
│    │  wg0 (WireGuard) │         │  eth0 (LAN Only) │   │
│    │  10.14.0.2/16    │         │  192.168.110.42  │   │
│    └─────────┬────────┘         └────────┬─────────┘   │
└──────────────┼───────────────────────────┼─────────────┘
               │ Encrypted VPN             │ Local LAN (NPM/SSO)
               ▼                           ▼
        Surfshark Los Angeles        Internal Services
      (89.187.187.87 Datacamp)       (192.168.0.0/16, etc.)
```

### Key Requirements:
1. **Zero WAN Leakage (Kill Switch):** All outbound traffic to the internet MUST traverse `wg0`. If `wg0` drops, `eth0` rejects all non-LAN WAN egress.
2. **Preserve LAN & Reverse Proxy Routing:** Internal subnets (`192.168.0.0/16`, `100.64.0.0/10`) must be explicitly routed via `eth0` gateway (`192.168.110.1`) so Nginx Proxy Manager (`192.168.120.211`) and LAN users can access Transmission, Sonarr, Radarr, and Readarr.
3. **Auto-start on Boot:** Persistent across container reboots via `systemd` service `wg-quick@wg0.service`.

---

## 3. Implementation Steps

### Step 1: Install Dependencies
Inside CT 417:
```bash
apt-get update
apt-get install -y wireguard-tools openresolv iptables curl
```

### Step 2: Generate Keypair & Register in Surfshark
Generated private key securely inside the container:
```bash
mkdir -p /etc/wireguard && chmod 700 /etc/wireguard
wg genkey | tee /etc/wireguard/private.key | wg pubkey > /etc/wireguard/public.key
chmod 600 /etc/wireguard/private.key
```
Registered Public Key under Surfshark Manual Setup -> Router -> WireGuard.

### Step 3: Configure WireGuard & Kill Switch (`/etc/wireguard/wg0.conf`)

```ini
[Interface]
Address = 10.14.0.2/16
PrivateKey = <CONTAINER_PRIVATE_KEY>
DNS = 162.252.172.57, 149.154.159.92

# Preserve LAN & Tailscale Routing
PostUp = ip route add 192.168.0.0/16 via 192.168.110.1 dev eth0 || true
PostUp = ip route add 100.64.0.0/10 via 192.168.110.1 dev eth0 || true

# Strict Kill Switch: Allow LAN + VPN endpoint, block raw WAN egress on eth0
PostUp = iptables -I OUTPUT 1 -o eth0 -d 192.168.0.0/16 -j ACCEPT
PostUp = iptables -I OUTPUT 2 -o eth0 -d 100.64.0.0/10 -j ACCEPT
PostUp = iptables -I OUTPUT 3 -o eth0 -p udp --dport 51820 -j ACCEPT
PostUp = iptables -I OUTPUT 4 -o wg0 -j ACCEPT
PostUp = iptables -A OUTPUT -o eth0 -j REJECT

# Teardown
PreDown = iptables -D OUTPUT -o eth0 -j REJECT || true
PreDown = iptables -D OUTPUT 1 || true
PreDown = iptables -D OUTPUT 1 || true
PreDown = iptables -D OUTPUT 1 || true
PreDown = iptables -D OUTPUT 1 || true
PreDown = ip route del 192.168.0.0/16 via 192.168.110.1 dev eth0 || true
PreDown = ip route del 100.64.0.0/10 via 192.168.110.1 dev eth0 || true

[Peer]
PublicKey = m+L7BVQWDwU2TxjfspMRLkRctvmo7fOkd+eVk6KC5lM=
AllowedIPs = 0.0.0.0/0
Endpoint = 89.187.187.86:51820
PersistentKeepalive = 25
```

### Step 4: Enable Service & Start
```bash
systemctl enable wg-quick@wg0
wg-quick up wg0
```

---

## 4. Verification & Validation

### 1. WireGuard Handshake
```bash
root@arr-stack-cebu:~# wg show
interface: wg0
  public key: <sanitized>
  listening port: 55202
  fwmark: 0xca6c

peer: m+L7BVQWDwU2TxjfspMRLkRctvmo7fOkd+eVk6KC5lM=
  endpoint: 89.187.187.86:51820
  allowed ips: 0.0.0.0/0
  latest handshake: Now
  transfer: 12.4 KiB received, 8.2 KiB sent
```

### 2. Public Egress IP Check (Surfshark Verified)
```bash
root@arr-stack-cebu:~# curl -s https://ipinfo.io/json
{
  "ip": "89.187.187.87",
  "hostname": "unn-89-187-187-87.cdn77.com",
  "city": "Los Angeles",
  "region": "California",
  "country": "US",
  "loc": "34.0522,-118.2437",
  "org": "AS60068 Datacamp Limited",
  "postal": "90013",
  "timezone": "America/Los_Angeles"
}
```

---

## 5. Ongoing Validation Commands

```bash
# Check WireGuard interface & handshake stats
pct exec 417 -- wg show

# Verify public IP is Surfshark (not ISP)
pct exec 417 -- curl -s https://ipinfo.io/json | grep ip
```
