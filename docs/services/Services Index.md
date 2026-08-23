# 🔧 Services Index

Master index of all running services in the Homelab-Net Homelab.  
Last updated: 2026-08-15

---

## Proxmox LXC Services (Bulakan — 192.168.1.25)

| Service | CT ID | VLAN / Subnet | IP Address | Status | Purpose |
|:---|:---:|:---:|:---:|:---:|:---|
| Audiobookshelf | 100 | VLAN 1 (Mgmt) | `192.168.1.59` | 🟢 Running | Audiobook server |
| Plex (Bulakan) | 104 | VLAN 1 (Mgmt) | `192.168.1.54` | 🟢 Running | Media server (Bulakan, 9th Gen QSV GPU) |
| Jackett | 108 | VLAN 1 (Mgmt) | `192.168.1.58` | 🟢 Running | Secondary tracker proxy |
| Jellyfin | 110 | VLAN 110 (Services) | `192.168.110.41` | 🟢 Running | Primary Jellyfin Media Server (QSV GPU) |
| Calibre-Web | 113 | VLAN 1 (Mgmt) | `DHCP` | 🟢 Running | Ebook library server (`/books` Synology mount) |
| Heimdall Dashboard | 115 | VLAN 1 (Mgmt) | `DHCP` | 🟢 Running | App dashboard |
| Homepage Dashboard | 116 | VLAN 1 (Mgmt) | `DHCP` | 🟢 Running | Central homelab portal |
| Pi-hole (Bulakan) | 301 | VLAN 1 (Mgmt) | `192.168.1.4` | 🟢 Running | Primary DNS ad-blocker & local resolver |
| Cloudflared (Bulakan) | 304 | VLAN 120 (DMZ) | `192.168.120.7` | 🟢 Running | Primary Cloudflare ingress tunnel |
| Nginx Proxy Manager (Standby) | 102 | VLAN 120 (DMZ) | `192.168.120.212` | ⚪ Stopped | Standby Failover Reverse Proxy |
| Netboot.xyz | 118 | VLAN 1 (Mgmt) | `192.168.1.54` | ⚪ Stopped | PXE network boot installer |

---

## Proxmox LXC Services (Cebu — 192.168.1.26)

| Service | CT ID | VLAN / Subnet | IP Address | Status | Purpose |
|:---|:---:|:---:|:---:|:---:|:---|
| Authentik | 103 | VLAN 110 (Services) | `192.168.110.225` | 🟢 Running | Identity Provider & SSO (`auth.homelab-admin.me`) |
| Nginx Proxy Manager (Cebu) | 105 | VLAN 120 (DMZ) | `192.168.120.211` | 🟢 Running | **Primary Reverse Proxy & Wildcard SSL** |
| Plex (Cebu) | 109 | VLAN 1 (Mgmt) | `DHCP` | 🟢 Running | Secondary Plex Media Server (QSV GPU) |
| Pi-hole (Cebu) | 401 | VLAN 1 (Mgmt) | `192.168.1.5` | 🟢 Running | Secondary DNS Failover Resolver |
| Cloudflared (Cebu) | 404 | VLAN 120 (DMZ) | `192.168.120.6` | 🟢 Running | Redundant Active Cloudflare Tunnel |
| Jellyfin (Cebu) | 416 | VLAN 110 (Services) | `192.168.110.42` | 🟢 Running | Standby Failover Jellyfin |
| Arr Stack Consolidated | 417 | VLAN 110 (Services) | `192.168.110.42` | 🟢 Running | Sonarr/Radarr/Prowlarr/Transmission (Surfshark WireGuard) |
| Wazuh SIEM & XDR | VM 250 | VLAN 10 (SecOps) | `192.168.10.250` | 🟢 Running | Threat Detection & SIEM Engine |

---

## Proxmox LXC Services (Dapitan — 192.168.1.27)

| Service | CT ID | VLAN / Subnet | IP Address | Status | Purpose |
|:---|:---:|:---:|:---:|:---:|:---|
| Immich (Dapitan) | 504 | VLAN 110 (Services) | `192.168.110.47` | 🟢 Running | Primary Photo/Video Vault (18TB ZFS) |
| Plex (Dapitan) | 509 | VLAN 110 (Services) | `192.168.110.44` | 🟢 Running | Bulk Media Server (18TB ZFS Direct Mount) |
| Jellyfin (Dapitan) | 510 | VLAN 110 (Services) | `192.168.110.43` | 🟢 Running | Secondary Jellyfin Server (18TB ZFS Direct Mount) |
| Apache Guacamole | 114 | VLAN 110 (Services) | `192.168.110.85` | 🟢 Running | Clientless Remote Desktop Gateway |
| Floci Stack | 512 | VLAN 110 (Services) | `192.168.110.49` | 🟢 Running | Multi-cloud Dev Stack |
| UEFI PXE Boot Server | 513 | VLAN 110 (Services) | `192.168.110.55` | 🟢 Running | Network PXE OS Deployment Server |
| BookOrbit | 514 | VLAN 110 (Services) | `192.168.110.50` | 🟢 Running | E-book Library Sync (`bookorbit.homelab-admin.me`) |
| Linux Mint Jump Box | VM 505 | VLAN 20 (Trusted) | `DHCP` | 🟢 Running | Remote Desktop Management Jump Box |
| Home Assistant OS (HAOS) | VM 111 | VLAN 1 (Mgmt) | `192.168.1.207` | 🟢 Running | Smart Home Controller |

---

## Proxmox VMs (Dapitan — 192.168.1.27)

| VM | ID | IP | Purpose |
|----|----|----|---------|
| mint-desktop-dapitan | 505 | 192.168.20.192 | Linux Mint 22 Remote Desktop Jump Box (**TRUSTED VLAN 20**) |

## Proxmox VMs (Bulakan)

| VM | ID | IP | Purpose |
|----|----|----|---------|
| Perlas-W10 | 201 | DHCP | Windows 10 daily-use desktop |
| Immich-UbuntuLTS | 204 | DHCP | Immich photo management platform (Decommissioned / Powered Off) |

---

## 🛑 DEPRECATED (Unraid — 192.168.1.24)
*Server crashed on 2026-05-13. Services moved to Proxmox Cebu/Bulakan.*

---

## Services by Category

### 📺 Media
- Jellyfin → http://192.168.1.126:8096 (Bulakan) / Cebu node (Replacing Unraid)
- Plex → Bulakan CT 104 (Proxmox LXC)
- Calibre-Web → http://192.168.1.115:8083 (Bulakan CT 113)
- BookOrbit → https://bookorbit.homelab-admin.me (Dapitan CT 514 — `192.168.110.50:3000`)

### 📥 Downloads / Arr Stack
- Sonarr → https://sonarr.homelab-admin.me (Cebu CT 417 — `192.168.110.42:8989`)
- Readarr → https://readarr.homelab-admin.me (Cebu CT 417 — `192.168.110.42:8787`)
- Radarr → Bulakan CT 105 | Bazarr → Bulakan CT 107
- Prowlarr → http://192.168.1.53:9696 (Bulakan)
- Jackett → Bulakan CT 108 | Transmission → https://torrent.homelab-admin.me (Cebu CT 417 — `192.168.110.42:9091`)

### 📸 Photos
- PhotoPrism → Bulakan CT 111
- Immich → Dapitan CT 504 (Primary: http://192.168.110.47:2283) | Bulakan VM 204 (Decommissioned / Powered Off)
- Photoview → Dapitan CT 511 (`https://photoview.homelab-admin.me`) | Source: `\\pnas\photo` (SMB)

### 🌐 Networking / Infrastructure
- WireGuard → Bulakan CT 101 (VPN)
- Pi-hole → Bulakan CT 301 + Cebu CT 401 (192.168.1.4)
- Cloudflared → Bulakan CT 304
- PNAS (Synology) → http://192.168.1.12:5001 (Shared PVE Storage)
- Netboot.xyz → Bulakan CT 118 → http://192.168.1.54:3000
- Authentik → https://auth.homelab-admin.me (SSO / IAM)
- Nginx Proxy Manager → http://192.168.120.211:81 (Admin Dashboard — Cebu CT 105, **Active**) ~~http://192.168.1.210~~ (Bulakan CT 502, **OFFLINE**)~~

### 🏠 Dashboards
- Homepage → https://home.homelab-admin.me (Bulakan CT 116 — `192.168.1.250:3000`)
- Heimdall → Bulakan CT 115
