# 🎬 Dapitan Plex Nginx Reverse Proxy & VLAN 110 Migration Guide (`plexdp.homelab-admin.me`)

> **Date:** 2026-08-15  
> **Objective:** Migrate Dapitan Plex Media Server (CT 509) to SERVICES VLAN 110 (`192.168.110.44:32400`) and establish secure remote reverse proxy access via Nginx Proxy Manager (`plexdp.homelab-admin.me`).  
> **Target Service:** Dapitan Plex CT 509 (`192.168.110.44:32400` — **SERVICES VLAN 110**)  
> **Reverse Proxy:** Nginx Proxy Manager (`192.168.120.211:81` — **Cebu CT 105 / DMZ VLAN 120**)  
> **Local DNS:** Pi-hole Primary (`192.168.1.4` CT 301) & Secondary (`192.168.1.134` CT 401)  
> **Status:** 🟢 Active (LAN-Only Reverse Proxy via Pi-hole & Let's Encrypt Wildcard SSL `*.homelab-admin.me` — Zero Open Ports)  

---

## 1. Architecture & Design Rationale

```
[ External / Remote Client ]
            │
            ▼
   [ Cloudflare DNS ] (plexdp.homelab-admin.me ──> WAN IP: 203.0.113.10, Grey Cloud / DNS Only)
            │
            ▼
[ UniFi UCG Max Gateway ] (WAN:443 / WAN:80 Port Forwarding)
            │
            ▼
[ Nginx Proxy Manager (Cebu CT 105) ] (192.168.120.211:443 — DMZ VLAN 120)
            │ (Wildcard SSL *.homelab-admin.me, HTTP/2, HSTS, Websockets, Streaming Directives)
            ▼
[ Plex Media Server (Dapitan CT 509) ] (192.168.110.44:32400 — SERVICES VLAN 110)
```

- **Cloudflare TOS Compliance:** Video streaming media is routed via **DNS-Only (Grey Cloud)** direct port forwarding, complying with Cloudflare TOS Section 2.8.
- **Network Segmentation:** CT 509 migrated to **SERVICES VLAN 110** (`192.168.110.44/24`), aligning with the homelab Class-C subnet schema.
- **SSL Protection:** NPM terminates TLS using the Let's Encrypt wildcard certificate (`*.homelab-admin.me`), enforcing HTTPS with HSTS and HTTP/2.
- **Local Loopback:** Pi-hole DNS resolves `plexdp.homelab-admin.me` directly to NPM (`192.168.120.211`) for zero-latency local LAN playback.

---

## 2. Infrastructure Parameters

| Parameter | Value | Details |
|---|---|---|
| **Host Node** | `Dapitan` (`192.168.1.27`) | Node 3 in `Homelab-Net` cluster |
| **Container ID** | `509` | Proxmox LXC container |
| **Hostname** | `plex-dapitan` | Container hostname |
| **Static IP Address** | `192.168.110.44/24` | Configured on `vmbr0`, `tag=110`, `gw=192.168.110.1` |
| **MAC Address** | `00:11:22:33:44:55` | Preserved hardware MAC address |
| **Internal Service Port** | `32400` (TCP) | Default Plex Media Server HTTP port |
| **Public FQDN** | `plexdp.homelab-admin.me` | Custom subdomain for Plex Dapitan |
| **Reverse Proxy Host** | `192.168.120.211:81` | Cebu CT 105 (NPM) |

---

## 3. Steps Executed

### Step 1: Migrate CT 509 to SERVICES VLAN 110
Executed on host `Dapitan` (`192.168.1.27`):
```bash
# Gracefully stop container
pct stop 509

# Reassign network interface to VLAN 110 with static IP 192.168.110.44/24
pct set 509 -net0 name=eth0,bridge=vmbr0,gw=192.168.110.1,hwaddr=00:11:22:33:44:55,ip=192.168.110.44/24,tag=110,type=veth

# Start container
pct start 509
```

### Step 2: Configure Cloudflare DNS A Record
Created DNS `A` record via Cloudflare API (`Zone: homelab-admin.me`):
- **Name:** `plexdp`
- **Type:** `A`
- **IPv4 Address:** `203.0.113.10` (Public WAN IP)
- **Proxy Status:** `false` (DNS-Only / Grey Cloud)
- **TTL:** Auto

### Step 3: Configure Pi-hole Local DNS Override
Added `192.168.120.211 plexdp.homelab-admin.me` to `/etc/pihole/custom.list` on:
- Bulakan Pi-hole Primary (CT 301)
- Cebu Pi-hole Secondary (CT 401)
Reloaded DNS lists via `/usr/local/bin/pihole restartdns reload-lists`.

### Step 4: Configure NPM Proxy Host on Cebu CT 105
Configured Proxy Host 12 in NPM database and generated `/data/nginx/proxy_host/12.conf`:
- **Domain:** `plexdp.homelab-admin.me`
- **Scheme:** `http`
- **Forward Host / Port:** `192.168.110.44:32400`
- **SSL:** `*.homelab-admin.me` (ID: 3)
- **Toggles:** Force SSL, HTTP/2 Support, HSTS Enabled, Websockets Support
- **Advanced Directives:**
  ```nginx
  proxy_buffering off;
  client_max_body_size 0;
  proxy_read_timeout 3600s;
  proxy_send_timeout 3600s;
  send_timeout 3600s;
  gzip on;
  gzip_vary on;
  gzip_min_length 1000;
  gzip_proxied any;
  gzip_types text/plain text/css text/xml application/xml text/javascript application/x-javascript image/svg+xml;
  ```

### Step 5: Update Plex Server Preferences on CT 509
Updated `/var/lib/plexmediaserver/Library/Application Support/Plex Media Server/Preferences.xml`:
- `customConnections="https://plexdp.homelab-admin.me:443"`
- `lanNetworks="192.168.110.0/24,192.168.1.0/24,192.168.120.0/24"`
- `RelayEnabled="0"`
Restarted `plexmediaserver.service`.

---

## 4. Verification & Validation Results

1. **Local Network IP Verification:**
   ```bash
   pct exec 509 -- ip addr show eth0
   # Result: inet 192.168.110.44/24 scope global eth0
   ```

2. **NPM to Plex HTTP Proxy Test:**
   ```bash
   pct exec 105 -- curl -Is http://192.168.110.44:32400/web
   # Result: HTTP/1.1 302 Moved Temporarily (Location: http://192.168.110.44:32400/web/index.html)
   ```

3. **HTTP to HTTPS 301 Redirection:**
   ```bash
   curl.exe -I http://plexdp.homelab-admin.me
   # Result: HTTP/1.1 301 Moved Permanently (Location: https://plexdp.homelab-admin.me/)
   ```

4. **HTTPS Web UI Access:**
   ```bash
   curl.exe -Ik https://plexdp.homelab-admin.me/web/index.html
   # Result: HTTP/1.1 200 OK (Strict-Transport-Security: max-age=63072000; preload)
   ```

5. **Plex Identity Endpoint:**
   ```bash
   curl.exe -s -k https://plexdp.homelab-admin.me/identity
   # Result: <MediaContainer size="0" apiVersion="1.1.1" claimed="1" machineIdentifier="5f2728511675384a67771a81fe991a537a528b99" version="1.42.2.10156-f737b826c">
   ```

---

## 5. Rollback Procedures

If rollback is needed:

1. **Revert CT 509 Network:**
   ```bash
   pct set 509 -net0 name=eth0,bridge=vmbr0,gw=192.168.1.1,hwaddr=00:11:22:33:44:55,ip=192.168.1.44/24,type=veth
   pct reboot 509
   ```

2. **Revert Plex Preferences:**
   ```bash
   systemctl stop plexmediaserver
   cp '/var/lib/plexmediaserver/Library/Application Support/Plex Media Server/Preferences.xml.bak-2026-08-15' '/var/lib/plexmediaserver/Library/Application Support/Plex Media Server/Preferences.xml'
   systemctl start plexmediaserver
   ```

3. **Revert NPM Proxy Host:**
   Inside CT 105, restore `/data/database.sqlite.bak-2026-08-15` to `/data/database.sqlite`, delete `/data/nginx/proxy_host/12.conf`, and run `nginx -s reload`.

4. **Revert Pi-hole DNS:**
   Remove `192.168.120.211 plexdp.homelab-admin.me` from `/etc/pihole/custom.list` on CT 301 and CT 401 and reload DNS.

---

## 6. References

- [Plex Nginx Reverse Proxy Guide - Plexopedia](https://www.plexopedia.com/plex-media-server/general/plex-nginx-reverse-proxy/)
- [Nginx Proxy Manager Setup & Operations](file:////opt/homelab-infrastructure/05-Services/Nginx%20Proxy%20Manager.md)
- [Class C Subnet & IP Allocation Schema Recommendation](file:////opt/homelab-infrastructure/04-Network/Class-C-Subnet-Schema-Recommendation.md)
- [Dapitan Plex Media Server Setup & Access Recovery Guide](file:////opt/homelab-infrastructure/06-Guides/Dapitan-Plex-Setup-Recovery-2026-07-24.md)
