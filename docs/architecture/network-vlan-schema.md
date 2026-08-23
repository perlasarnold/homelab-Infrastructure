# 🌐 Network Overview

> **Cluster Name:** `Homelab-Net`
> **Gateway:** `VLAN 1 [Gateway]` (Perlas-UnifiGW) | **Subnet:** `VLAN 1 (Management)/24`
> **Primary DNS:** `VLAN 1 [Primary DNS]` (PX-Pihole Bulakan) | **Secondary DNS:** `VLAN 1 [Secondary DNS]` (pihole-cebu)

---

## IP Address Map

| IP Address | Hostname / ID | Device / Role | VLAN Segment | Status |
|:---|:---|:---|:---|:---|
| `VLAN 1 [Gateway]` | Perlas-UnifiGW | UniFi UCG Max Gateway | VLAN 1 (Mgmt) | 🟢 Default Gateway |
| `VLAN 1 [Primary DNS]` | pihole (CT 301) | Primary DNS Ad-blocker & Local Resolver | VLAN 1 (Mgmt) | 🟢 Active |
| `VLAN 1 [Secondary DNS]` | pihole-cebu (CT 401) | Secondary DNS Failover Resolver | VLAN 1 (Mgmt) | 🟢 Active |
| `VLAN 1 [Management]` | PNAS | Synology NAS (23TB CIFS/NFS Shared Storage) | VLAN 1 (Mgmt) | 🟢 Active |
| `VLAN 1 [Management]` | PNAS2 | Secondary Synology (Backup Storage) | VLAN 1 (Mgmt) | 🟢 Active |
| `VLAN 1 [Management]` | Bulakan | Proxmox VE Primary Hypervisor Node | VLAN 1 (Mgmt) | 🟢 Active |
| `VLAN 1 [Management]` | Cebu | Proxmox VE Secondary Hypervisor Node | VLAN 1 (Mgmt) | 🟢 Active |
| `VLAN 1 [Management]` | Dapitan | Proxmox VE Bulk Storage Node (18TB ZFS) | VLAN 1 (Mgmt) | 🟢 Active |
| `VLAN 1 [Management]` | plex (CT 104) | Primary Plex Media Server (Bulakan ZFS) | VLAN 1 (Mgmt) | 🟢 Active |
| `VLAN 1 [Management]` | audiobookshelf (CT 100) | Audiobook library & streaming server | VLAN 1 (Mgmt) | 🟢 Active |
| `VLAN 1 [Management]` | haos-17.3 (VM 111) | Home Assistant OS Controller (Dapitan) | VLAN 1 (Mgmt) | 🟢 Active |
| `VLAN 10 (SecOps)` | wazuh-siem (VM 250) | Wazuh SIEM & Security Threat Analytics (Cebu) | VLAN 10 (SecOps) | 🟢 Active |
| `VLAN 110 (Services)` | jellyfin (CT 110) | Primary Jellyfin Media Server (Bulakan) | VLAN 110 (Services) | 🟢 Active |
| `VLAN 110 (Services)` | arr-stack-cebu (CT 417) | Consolidated Arr Stack (Sonarr/Radarr/Prowlarr/Transmission) | VLAN 110 (Services) | 🟢 Active |
| `VLAN 110 (Services)` | jellyfin-cebu (CT 416) | Standby Failover Jellyfin (Cebu) | VLAN 110 (Services) | 🟢 Active |
| `VLAN 110 (Services)` | jellyfin-dapitan (CT 510) | Secondary Jellyfin Server (Dapitan 18TB ZFS) | VLAN 110 (Services) | 🟢 Active |
| `VLAN 110 (Services)` | plex-dapitan (CT 509) | Bulk Plex Media Server (Dapitan 18TB ZFS) | VLAN 110 (Services) | 🟢 Active |
| `VLAN 110 (Services)` | immich-dapitan (CT 504) | Primary Photo Vault (Dapitan 18TB ZFS) | VLAN 110 (Services) | 🟢 Active |
| `VLAN 110 (Services)` | floci-dapitan (CT 512) | Floci Multi-Cloud Dev Stack | VLAN 110 (Services) | 🟢 Active |
| `VLAN 110 (Services)` | bookorbit-dapitan (CT 514) | BookOrbit Ebook Platform | VLAN 110 (Services) | 🟢 Active |
| `VLAN 110 (Services)` | pxe-dapitan (CT 513) | UEFI/BIOS PXE Boot & Kickstart Server | VLAN 110 (Services) | 🟢 Active |
| `VLAN 110 (Services)` | apache-guacamole (CT 114) | Clientless Remote Desktop Gateway | VLAN 110 (Services) | 🟢 Active |
| `VLAN 110 (Services)` | authentik (CT 103) | Central SSO Identity Provider & MFA (Cebu) | VLAN 110 (Services) | 🟢 Active |
| `VLAN 120 (DMZ)` | cloudflared-cebu (CT 404) | Active Redundant Cloudflare Tunnel (Cebu) | VLAN 120 (DMZ) | 🟢 Active |
| `VLAN 120 (DMZ)` | cloudflared (CT 304) | Primary Cloudflare Ingress Tunnel (Bulakan) | VLAN 120 (DMZ) | 🟢 Active |
| `VLAN 120 (DMZ)` | nginxproxymanager (CT 105) | Primary Active Reverse Proxy & Wildcard SSL (Cebu) | VLAN 120 (DMZ) | 🟢 Active |
| `VLAN 120 (DMZ)` | nginxproxymanager (CT 102) | Standby Failover Reverse Proxy (Bulakan) | VLAN 120 (DMZ) | ⚪ Stopped |

---

## DNS

| Resolver | Address | Node / Container | Status |
|:---|:---|:---|:---|
| Primary | `VLAN 1 [Primary DNS]` | Bulakan (CT 301: pihole) | 🟢 Active |
| Secondary | `VLAN 1 [Secondary DNS]` | Cebu (CT 401: pihole-cebu) | 🟢 Active |
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
| Media streams (Plex, Jellyfin) | Port Forwarding → NPM Cebu (`VLAN 120 (DMZ)`) | WAN:443/80 → NPM; NPM routes by subdomain |

---

## VLAN Segmentation

The network is segmented into standardized Class C subnets (`192.168.x.x /24`) aligned with 802.1Q VLAN IDs for isolation and traffic management:

| VLAN | Name | Subnet | Gateway | Purpose |
|:-----|:-----|:-------|:--------|:--------|
| 1 | Default | `VLAN 1 (Management)/24` | `VLAN 1 [Gateway]` | Legacy Management & Native Workloads |
| 10 | MGMT | `VLAN 10 (SecOps)/24` | `VLAN 10 (SecOps)` | Hypervisor Hosts, Switches, APs, Storage DSM/Web GUIs |
| 20 | TRUSTED | `VLAN 20 (Trusted)/24` | `VLAN 20 (Trusted)` | Admin Workstations, Daily Laptops, Mobile Devices |
| 30 | IOT | `VLAN 30 (IoT)/24` | `VLAN 30 [Gateway]` | Home Assistant OS, Smart TVs, IoT Sensors |
| 110 | SERVICES | `VLAN 110 (Services)/24` *(or `42.0/24`)* | `VLAN 110 (Services)` | Internal Homelab Services (Plex, Arr stack, Immich) |
| 120 | DMZ | `VLAN 120 (DMZ)/24` | `VLAN 120 (DMZ)` | Public Ingress Controllers (Cloudflared, NPM) |

---

## Related Pages

- [Class C Subnet & IP Allocation Schema Recommendation](file:////opt/homelab-infrastructure/04-Network/Class-C-Subnet-Schema-Recommendation.md)
- [UniFi Preemptive Foundation Setup Guide](file:////opt/homelab-infrastructure/04-Network/UniFi-Preemptive-Foundation-Setup.md)
- [UniFi Router & Network Setup](file:////opt/homelab-infrastructure/04-Network/UniFi%20Router%20Setup.md)
- [Proxmox Overview](file:////opt/homelab-infrastructure/02-Proxmox/Proxmox%20Overview.md)
- [Unraid Overview](file:////opt/homelab-infrastructure/03-Unraid/Unraid%20Overview.md)
- [Services Master Index](file:////opt/homelab-infrastructure/05-Services/Services%20Index.md)

