# 🔧 Services Index

Master index of all running services in the Homelab-Net Homelab.  
Last updated: 2026-08-15

---

## Proxmox LXC Services (Bulakan — VLAN 1 [MGMT])

| Service | CT ID | VLAN / Subnet | IP Address | Status | Purpose |
|:---|:---:|:---:|:---:|:---:|:---|
| Audiobookshelf | 100 | VLAN 1 (Mgmt) | `VLAN 1 (Mgmt)` | 🟢 Running | Audiobook server |
| Plex (Bulakan) | 104 | VLAN 1 (Mgmt) | `VLAN 1 (Mgmt)` | 🟢 Running | Media server (Bulakan, 9th Gen QSV GPU) |
| Jackett | 108 | VLAN 1 (Mgmt) | `VLAN 1 (Mgmt)` | 🟢 Running | Secondary tracker proxy |
| Jellyfin | 110 | VLAN 110 (Services) | `VLAN 110 (Services)` | 🟢 Running | Primary Jellyfin Media Server (QSV GPU) |
| Calibre-Web | 113 | VLAN 1 (Mgmt) | `DHCP` | 🟢 Running | Ebook library server (`/books` Synology mount) |
| Heimdall Dashboard | 115 | VLAN 1 (Mgmt) | `DHCP` | 🟢 Running | App dashboard |
| Homepage Dashboard | 116 | VLAN 1 (Mgmt) | `DHCP` | 🟢 Running | Central homelab portal |
| Pi-hole (Bulakan) | 301 | VLAN 1 (Mgmt) | `VLAN 1 [DNS-Primary]` | 🟢 Running | Primary DNS ad-blocker & local resolver |
| Cloudflared (Bulakan) | 304 | VLAN 120 (DMZ) | `VLAN 120 (DMZ)` | 🟢 Running | Primary Cloudflare ingress tunnel |
| Nginx Proxy Manager (Standby) | 102 | VLAN 120 (DMZ) | `VLAN 120 (DMZ)` | ⚪ Stopped | Standby Failover Reverse Proxy |
| Netboot.xyz | 118 | VLAN 1 (Mgmt) | `VLAN 1 (Mgmt)` | ⚪ Stopped | PXE network boot installer |

---

## Proxmox LXC Services (Cebu — VLAN 1 [MGMT])

| Service | CT ID | VLAN / Subnet | IP Address | Status | Purpose |
|:---|:---:|:---:|:---:|:---:|:---|
| Authentik | 103 | VLAN 110 (Services) | `VLAN 110 (Services)` | 🟢 Running | Identity Provider & SSO (`auth.homelab-admin.me`) |
| Nginx Proxy Manager (Cebu) | 105 | VLAN 120 (DMZ) | `VLAN 120 (DMZ)` | 🟢 Running | **Primary Reverse Proxy & Wildcard SSL** |
| Plex (Cebu) | 109 | VLAN 1 (Mgmt) | `DHCP` | 🟢 Running | Secondary Plex Media Server (QSV GPU) |
| Pi-hole (Cebu) | 401 | VLAN 1 (Mgmt) | `VLAN 1 [DNS-Secondary]` | 🟢 Running | Secondary DNS Failover Resolver |
| Cloudflared (Cebu) | 404 | VLAN 120 (DMZ) | `VLAN 120 (DMZ)` | 🟢 Running | Redundant Active Cloudflare Tunnel |
| Jellyfin (Cebu) | 416 | VLAN 110 (Services) | `VLAN 110 (Services)` | 🟢 Running | Standby Failover Jellyfin |
| Arr Stack Consolidated | 417 | VLAN 110 (Services) | `VLAN 110 (Services)` | 🟢 Running | Sonarr/Radarr/Prowlarr/Transmission (Surfshark WireGuard) |
| Wazuh SIEM & XDR | VM 250 | VLAN 10 (SecOps) | `VLAN 10 (SecOps)` | 🟢 Running | Threat Detection & SIEM Engine |

---

## Proxmox LXC Services (Dapitan — VLAN 1 [MGMT])

| Service | CT ID | VLAN / Subnet | IP Address | Status | Purpose |
|:---|:---:|:---:|:---:|:---:|:---|
| Immich (Dapitan) | 504 | VLAN 110 (Services) | `VLAN 110 (Services)` | 🟢 Running | Primary Photo/Video Vault (18TB ZFS) |
| Plex (Dapitan) | 509 | VLAN 110 (Services) | `VLAN 110 (Services)` | 🟢 Running | Bulk Media Server (18TB ZFS Direct Mount) |
| Jellyfin (Dapitan) | 510 | VLAN 110 (Services) | `VLAN 110 (Services)` | 🟢 Running | Secondary Jellyfin Server (18TB ZFS Direct Mount) |
| Apache Guacamole | 114 | VLAN 110 (Services) | `VLAN 110 (Services)` | 🟢 Running | Clientless Remote Desktop Gateway |
| Floci Stack | 512 | VLAN 110 (Services) | `VLAN 110 (Services)` | 🟢 Running | Multi-cloud Dev Stack |
| UEFI PXE Boot Server | 513 | VLAN 110 (Services) | `VLAN 110 (Services)` | 🟢 Running | Network PXE OS Deployment Server |
| BookOrbit | 514 | VLAN 110 (Services) | `VLAN 110 (Services)` | 🟢 Running | E-book Library Sync (`bookorbit.homelab-admin.me`) |
| Linux Mint Jump Box | VM 505 | VLAN 20 (Trusted) | `DHCP` | 🟢 Running | Remote Desktop Management Jump Box |
| Home Assistant OS (HAOS) | VM 111 | VLAN 1 (Mgmt) | `VLAN 1 (Mgmt)` | 🟢 Running | Smart Home Controller |

---

## Proxmox VMs (Dapitan — VLAN 1 [MGMT])

| VM | ID | IP | Purpose |
|----|----|----|---------|
| mint-desktop-dapitan | 505 | VLAN 20 (Trusted) | Linux Mint 22 Remote Desktop Jump Box (**TRUSTED VLAN 20**) |

## Proxmox VMs (Bulakan)

| VM | ID | IP | Purpose |
|----|----|----|---------|
| Perlas-W10 | 201 | DHCP | Windows 10 daily-use desktop |
| Immich-UbuntuLTS | 204 | DHCP | Immich photo management platform (Decommissioned / Powered Off) |

---

## 🛑 DEPRECATED (Unraid — VLAN 1 (Mgmt))
*Server crashed on 2026-05-13. Services moved to Proxmox Cebu/Bulakan.*

---

## Services by Category

### 📺 Media
- Jellyfin → http://VLAN 1 (Mgmt):8096 (Bulakan) / Cebu node (Replacing Unraid)
- Plex → Bulakan CT 104 (Proxmox LXC)
- Calibre-Web → http://VLAN 1 (Mgmt):8083 (Bulakan CT 113)
- BookOrbit → https://bookorbit.homelab-admin.me (Dapitan CT 514 — `VLAN 110 (Services):3000`)

### 📥 Downloads / Arr Stack
- Sonarr → https://sonarr.homelab-admin.me (Cebu CT 417 — `VLAN 110 (Services):8989`)
- Readarr → https://readarr.homelab-admin.me (Cebu CT 417 — `VLAN 110 (Services):8787`)
- Radarr → Bulakan CT 105 | Bazarr → Bulakan CT 107
- Prowlarr → http://VLAN 1 (Mgmt):9696 (Bulakan)
- Jackett → Bulakan CT 108 | Transmission → https://torrent.homelab-admin.me (Cebu CT 417 — `VLAN 110 (Services):9091`)

### 📸 Photos
- PhotoPrism → Bulakan CT 111
- Immich → Dapitan CT 504 (Primary: http://VLAN 110 (Services):2283) | Bulakan VM 204 (Decommissioned / Powered Off)
- Photoview → Dapitan CT 511 (`https://photoview.homelab-admin.me`) | Source: `\\pnas\photo` (SMB)

### 🌐 Networking / Infrastructure
- WireGuard → Bulakan CT 101 (VPN)
- Pi-hole → Bulakan CT 301 + Cebu CT 401 (VLAN 1 [DNS-Primary])
- Cloudflared → Bulakan CT 304
- PNAS (Synology) → http://VLAN 1 [MGMT-NAS]:5001 (Shared PVE Storage)
- Netboot.xyz → Bulakan CT 118 → http://VLAN 1 (Mgmt):3000
- Authentik → https://auth.homelab-admin.me (SSO / IAM)
- Nginx Proxy Manager → http://VLAN 120 (DMZ):81 (Admin Dashboard — Cebu CT 105, **Active**) ~~http://VLAN 1 (Mgmt)~~ (Bulakan CT 502, **OFFLINE**)~~

### 🏠 Dashboards
- Homepage → https://home.homelab-admin.me (Bulakan CT 116 — `VLAN 1 (Mgmt):3000`)
- Heimdall → Bulakan CT 115
