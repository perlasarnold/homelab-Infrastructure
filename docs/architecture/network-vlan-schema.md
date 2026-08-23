# 🌐 Network Overview

> **Cluster Name:** `Homelab-Net`
> **Gateway:** `192.168.1.1` (Perlas-UnifiGW) | **Subnet:** `192.168.1.0/24`
> **Primary DNS:** `192.168.1.4` (PX-Pihole Bulakan) | **Secondary DNS:** `192.168.1.5` (pihole-cebu)

---

## IP Address Map

| IP Address | Hostname / ID | Device / Role | VLAN Segment | Status |
|:---|:---|:---|:---|:---|
| `192.168.1.1` | Perlas-UnifiGW | UniFi UCG Max Gateway | VLAN 1 (Mgmt) | 🟢 Default Gateway |
| `192.168.1.4` | pihole (CT 301) | Primary DNS Ad-blocker & Local Resolver | VLAN 1 (Mgmt) | 🟢 Active |
| `192.168.1.5` | pihole-cebu (CT 401) | Secondary DNS Failover Resolver | VLAN 1 (Mgmt) | 🟢 Active |
| `192.168.1.12` | PNAS | Synology NAS (23TB CIFS/NFS Shared Storage) | VLAN 1 (Mgmt) | 🟢 Active |
| `192.168.1.13` | PNAS2 | Secondary Synology (Backup Storage) | VLAN 1 (Mgmt) | 🟢 Active |
| `192.168.1.25` | Bulakan | Proxmox VE Primary Hypervisor Node | VLAN 1 (Mgmt) | 🟢 Active |
| `192.168.1.26` | Cebu | Proxmox VE Secondary Hypervisor Node | VLAN 1 (Mgmt) | 🟢 Active |
| `192.168.1.27` | Dapitan | Proxmox VE Bulk Storage Node (18TB ZFS) | VLAN 1 (Mgmt) | 🟢 Active |
| `192.168.1.54` | plex (CT 104) | Primary Plex Media Server (Bulakan ZFS) | VLAN 1 (Mgmt) | 🟢 Active |
| `192.168.1.59` | audiobookshelf (CT 100) | Audiobook library & streaming server | VLAN 1 (Mgmt) | 🟢 Active |
| `192.168.1.207` | haos-17.3 (VM 111) | Home Assistant OS Controller (Dapitan) | VLAN 1 (Mgmt) | 🟢 Active |
| `192.168.10.250` | wazuh-siem (VM 250) | Wazuh SIEM & Security Threat Analytics (Cebu) | VLAN 10 (SecOps) | 🟢 Active |
| `192.168.110.41` | jellyfin (CT 110) | Primary Jellyfin Media Server (Bulakan) | VLAN 110 (Services) | 🟢 Active |
| `192.168.110.42` | arr-stack-cebu (CT 417) | Consolidated Arr Stack (Sonarr/Radarr/Prowlarr/Transmission) | VLAN 110 (Services) | 🟢 Active |
| `192.168.110.42` | jellyfin-cebu (CT 416) | Standby Failover Jellyfin (Cebu) | VLAN 110 (Services) | 🟢 Active |
| `192.168.110.43` | jellyfin-dapitan (CT 510) | Secondary Jellyfin Server (Dapitan 18TB ZFS) | VLAN 110 (Services) | 🟢 Active |
| `192.168.110.44` | plex-dapitan (CT 509) | Bulk Plex Media Server (Dapitan 18TB ZFS) | VLAN 110 (Services) | 🟢 Active |
| `192.168.110.47` | immich-dapitan (CT 504) | Primary Photo Vault (Dapitan 18TB ZFS) | VLAN 110 (Services) | 🟢 Active |
| `192.168.110.49` | floci-dapitan (CT 512) | Floci Multi-Cloud Dev Stack | VLAN 110 (Services) | 🟢 Active |
| `192.168.110.50` | bookorbit-dapitan (CT 514) | BookOrbit Ebook Platform | VLAN 110 (Services) | 🟢 Active |
| `192.168.110.55` | pxe-dapitan (CT 513) | UEFI/BIOS PXE Boot & Kickstart Server | VLAN 110 (Services) | 🟢 Active |
| `192.168.110.85` | apache-guacamole (CT 114) | Clientless Remote Desktop Gateway | VLAN 110 (Services) | 🟢 Active |
| `192.168.110.225` | authentik (CT 103) | Central SSO Identity Provider & MFA (Cebu) | VLAN 110 (Services) | 🟢 Active |
| `192.168.120.6` | cloudflared-cebu (CT 404) | Active Redundant Cloudflare Tunnel (Cebu) | VLAN 120 (DMZ) | 🟢 Active |
| `192.168.120.7` | cloudflared (CT 304) | Primary Cloudflare Ingress Tunnel (Bulakan) | VLAN 120 (DMZ) | 🟢 Active |
| `192.168.120.211` | nginxproxymanager (CT 105) | Primary Active Reverse Proxy & Wildcard SSL (Cebu) | VLAN 120 (DMZ) | 🟢 Active |
| `192.168.120.212` | nginxproxymanager (CT 102) | Standby Failover Reverse Proxy (Bulakan) | VLAN 120 (DMZ) | ⚪ Stopped |

---

## DNS

| Resolver | Address | Node / Container | Status |
|:---|:---|:---|:---|
| Primary | `192.168.1.4` | Bulakan (CT 301: pihole) | 🟢 Active |
| Secondary | `192.168.1.5` | Cebu (CT 401: pihole-cebu) | 🟢 Active |
| Upstream | `1.1.1.1` / `8.8.8.8` | Cloudflare / Google | Upstream Resolver |
| Upstream | 1.1.1.1 / 8.8.8.8 | Cloudflare/Google |

---

## NIC Bonding (Proxmox)

Bulakan uses an **active-backup bond** for network redundancy:
- `enp1s0` — onboard Intel NIC (primary)
- `enx000000000000` — USB Realtek RTL8152 NIC (backup)

If the primary NIC fails, traffic automatically fails over to the USB NIC.

---

## Port Forwarding / External Access

| Service | Method | Notes |
|---------|--------|-------|
| All external services | Cloudflare Tunnel (`cloudflared`) | No open ports on router |
| Media streams (Plex, Jellyfin) | Port Forwarding → NPM Cebu (`192.168.120.211`) | WAN:443/80 → NPM; NPM routes by subdomain |

---

## VLAN Segmentation

The network is segmented into standardized Class C subnets (`192.168.x.x /24`) aligned with 802.1Q VLAN IDs for isolation and traffic management:

| VLAN | Name | Subnet | Gateway | Purpose |
|:-----|:-----|:-------|:--------|:--------|
| 1 | Default | `192.168.1.0/24` | `192.168.1.1` | Legacy Management & Native Workloads |
| 10 | MGMT | `192.168.10.0/24` | `192.168.10.1` | Hypervisor Hosts, Switches, APs, Storage DSM/Web GUIs |
| 20 | TRUSTED | `192.168.20.0/24` | `192.168.20.1` | Admin Workstations, Daily Laptops, Mobile Devices |
| 30 | IOT | `192.168.30.0/24` | `192.168.30.1` | Home Assistant OS, Smart TVs, IoT Sensors |
| 110 | SERVICES | `192.168.110.0/24` *(or `42.0/24`)* | `192.168.110.1` | Internal Homelab Services (Plex, Arr stack, Immich) |
| 120 | DMZ | `192.168.120.0/24` | `192.168.120.1` | Public Ingress Controllers (Cloudflared, NPM) |

---

## Related Pages

- [Class C Subnet & IP Allocation Schema Recommendation](file:////opt/homelab-infrastructure/04-Network/Class-C-Subnet-Schema-Recommendation.md)
- [UniFi Preemptive Foundation Setup Guide](file:////opt/homelab-infrastructure/04-Network/UniFi-Preemptive-Foundation-Setup.md)
- [UniFi Router & Network Setup](file:////opt/homelab-infrastructure/04-Network/UniFi%20Router%20Setup.md)
- [Proxmox Overview](file:////opt/homelab-infrastructure/02-Proxmox/Proxmox%20Overview.md)
- [Unraid Overview](file:////opt/homelab-infrastructure/03-Unraid/Unraid%20Overview.md)
- [Services Master Index](file:////opt/homelab-infrastructure/05-Services/Services%20Index.md)

