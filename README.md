# 🏠 Homelab-Net / Core Homelab Vault

[![PVE Version](https://img.shields.io/badge/Proxmox_VE-8.4.18-orange?logo=proxmox&logoColor=white&style=flat-square)](https://www.proxmox.com)
[![Status](https://img.shields.io/badge/Cluster_Status-🟢_Active-success?style=flat-square)](#)
[![Infrastructure](https://img.shields.io/badge/Infrastructure-Hybrid_IaC-blue?logo=terraform&logoColor=white&style=flat-square)](#)
[![Secrets](https://img.shields.io/badge/Secrets_Policy-Strictly_Encrypted-red?style=flat-square)](#)

Welcome to the **Homelab-Net / Core Homelab and Documentation Vault**. This repository acts as the complete operational "brain" for our home server network, written to ensure that the entire environment is fully transparent, reproducible, and easily maintainable.

> [!WARNING]
> **SECRETS POLICY:** Strictly **no plain-text passwords, private keys, API tokens, or credentials** are allowed in this vault. All infrastructure secrets must be handled through Authentik (SSO) or local credentials files excluded from Git.

---

## 🗺️ Cluster Topology & Data Flow

Our homelab has evolved into a resilient, multi-node **Proxmox Virtual Environment** cluster connected with high-speed local storage, shared Synology NAS storage, Dapitan bulk ZFS storage, and an automated media stack.

```
                  ┌───────────────────────┐
                  │ UniFi UCG Max Gateway │ (192.168.1.1)
                  └───────────┬───────────┘
                              │
            ┌─────────────────┼─────────────────┐
            ▼                 ▼                 ▼
┌──────────────────────┐ ┌──────────────────────┐ ┌──────────────────────┐
│   Proxmox BULAKAN    │ │     Proxmox CEBU     │ │   Proxmox DAPITAN    │
│   (Primary Node)     │ │   (Secondary Node)   │ │  (Bulk Storage Node) │
│    192.168.1.25      │ │     192.168.1.26     │ │    192.168.1.27      │
└───────────┬──────────┘ └───────────┬──────────┘ └───────────┬──────────┘
            │                        │                        │
            ├─► LXC Containers       ├─► LXC Containers       ├─► 18TB ZFS Storage
            │   (Arr Stack, Plex,    │   (Authentik, NPM,     │   (/mnt/bindmounts/
            │    Jellyfin, PiHole)   │    Pi-Hole, Wazuh)     │    media-data)
            │                        │                        │
            └─► VMs (Win10)          └─► VMs (Win10, HAOS)    └─► LXC Containers
                                                                  (Immich, Plex,
                                                                   Jellyfin, Photo)
            ┌─────────────────────────────────────────────────────────────┐
            │                  Active Network Storage                     │
            │  1. PNAS Synology (192.168.1.12) ── Shared PVE & Media      │
            │  2. Dapitan Local Debian Share (192.168.1.27) ── 18TB ZFS   │
            └─────────────────────────────────────────────────────────────┘
```

---

## 🖥️ Core Infrastructure Nodes

### 1. Proxmox Bulakan (`192.168.1.25`)
* **Hardware & OS:** Intel Core i5-9500T (6 Cores) | 32GB RAM | PVE 9.2.5
* **Network Redundancy:** Active-Backup Bond (`bond0`) combining onboard Intel NIC (`enp1s0`) and a backup USB Realtek NIC (`enx000000000000`) to ensure zero-downtime path failover.
* **Storage Pools:** `Bulakan-ZFS` (2TB SSD ZFS pool) + mounted Synology storage.
* **Role:** Primary Node. Runs core services, the primary reverse proxy, and media orchestration. Bulakan containers are managed manually using helper scripts to ensure high runtime stability.

### 2. Proxmox Cebu (`192.168.1.26`)
* **Hardware & Storage:** Local `cebu-zfs` pool (2TB SSD) | Mounted Synology shares (`PNAS-Seagate`).
* **Role:** Replication Target, Secondary Core, and Backup target. Hosts active services including Authentik SSO, primary Nginx Proxy Manager (`npm-cebu`), and security SIEM.

### 3. Proxmox Dapitan (`192.168.1.27`)
* **Hardware & Storage:** Dell OptiPlex 7050 SFF | Intel Core i5-7500 | 40 GiB RAM | 1TB NVMe `vm-fast` + 18TB Seagate IronWolf ZFS `bulk18`.
* **Storage Shares:** Local Debian share & bind mounts at `/mnt/bindmounts/media-data`, `/mnt/bindmounts/immich-data`, and `/mnt/bindmounts/shared`.
* **Role:** Bulk media and photo application node hosting Immich, Plex DP, Jellyfin DP, and Photoview.

### 4. Synology NAS (`192.168.1.12` / `192.168.1.13`)
* **Active Storage:** `PNAS` (23TB CIFS/SMB) serving as shared storage for VM backups, ISO templates, and shared application files.
* **Backup Sync:** Synology `Seagate` shares are backed up across nodes using custom-scheduled Rsync transfers.

### 4. Legacy Unraid Server (`192.168.1.24`) — ⚠️ CRASHED & DEPRECATED
* **Status:** Retired. Following a complete hardware crash on **2026-05-13**, the Unraid server was taken offline permanently. All storage arrays and container applications have been migrated to the Proxmox **Cebu** and **Bulakan** hypervisors.

---

## 🌐 Network Configuration & Security

* **Gateway:** UniFi Cloud Gateway Max (`192.168.1.1`) managing internal segmentation.
* **VLAN Layout:**
  * **VLAN 1 (Management):** `192.168.1.0/24` — Dedicated to trusted admin interfaces, switches, and Proxmox hypervisor nodes.
  * **VLAN 110 (Internal):** `192.168.42.0/24` — Internal homelab servers, media apps, and databases.
  * **VLAN 2 (External):** `192.168.120.0/24` — DMZ segment for outward-facing reverse proxy interfaces.
* **DNS Resolution:**
  * **Primary DNS:** `192.168.1.5` (Pi-hole on Bulakan node, ad-blocking & local domain resolution)
  * **Secondary DNS:** `192.168.1.134` (Pi-hole on Cebu node, fully mirrored redundancy)
* **Access Control:**
  * **Internal Reverse Proxy:** Dual Nginx Proxy Manager (NPM) hosts on Bulakan and Cebu (`192.168.1.210`) running SSL termination.
  * **Identity Provider (IdP):** Centralized Single Sign-On (SSO) with **Authentik** (`https://auth.homelab-admin.me`), enforcing multi-factor authentication for sensitive administrative interfaces.
  * **Remote Access:** Encrypted **Cloudflare Tunnels** (`cloudflared`) on both nodes providing external ingress without forwarding physical router ports. A fallback **WireGuard** VPN CT (`CT 101`) allows direct console routing.

---

## 🔧 Master Service Catalog

All containerized and virtualized services mapped by hypervisor node, VLAN segment, and functional category (live-verified across Proxmox cluster):

| Category | Service Name | CT/VM ID | Host Node | VLAN / Subnet | IP Address | Status / Purpose |
|:---|:---|:---:|:---:|:---:|:---:|:---|
| **Identity & SSO** | Authentik | CT 103 | Cebu | VLAN 110 (Internal) | `192.168.110.225` | 🟢 Central Identity Management & MFA |
| **Reverse Proxy** | Nginx Proxy Manager (Primary) | CT 105 | Cebu | VLAN 120 (DMZ) | `192.168.120.211` | 🟢 Primary Reverse Proxy / SSL Ingress |
| | Nginx Proxy Manager (Standby) | CT 102 | Bulakan | VLAN 120 (DMZ) | `192.168.120.212` | ⚪ Failover Reverse Proxy (Stopped) |
| **Ingress Tunnels**| Cloudflared (Bulakan) | CT 304 | Bulakan | VLAN 120 (DMZ) | `192.168.120.7` | 🟢 Primary Cloudflare Ingress Tunnel |
| | Cloudflared (Cebu) | CT 404 | Cebu | VLAN 120 (DMZ) | `192.168.120.6` | 🟢 Redundant Active Cloudflare Tunnel |
| **Core DNS** | Pi-hole (Primary) | CT 301 | Bulakan | VLAN 1 (Mgmt) | `192.168.1.4` | 🟢 Primary DNS ad-blocker & local resolver |
| | Pi-hole (Secondary) | CT 401 | Cebu | VLAN 1 (Mgmt) | `192.168.1.5` | 🟢 Secondary DNS failover resolver |
| **Arr Stack** | Arr Stack Consolidated (Sonarr/Radarr/Prowlarr/Transmission/Jackett/Bazarr) | CT 417 | Cebu | VLAN 110 (Internal) | `192.168.110.42` | 🟢 Complete media acquisition stack with Surfshark WireGuard killswitch |
| **Media Servers** | Plex Media Server (Primary) | CT 104 | Bulakan | VLAN 1 (Mgmt) | `192.168.1.54` | 🟢 Primary Media Server (Bulakan ZFS) |
| | Plex Media Server (Dapitan) | CT 509 | Dapitan | VLAN 110 (Internal) | `192.168.110.44` | 🟢 Bulk Media Server (18TB ZFS mount) |
| | Jellyfin (Primary) | CT 110 | Bulakan | VLAN 110 (Internal) | `192.168.110.41` | 🟢 Primary Jellyfin Media Server |
| | Jellyfin (Cebu Standby) | CT 416 | Cebu | VLAN 110 (Internal) | `192.168.110.42` | 🟢 Failover Jellyfin instance |
| | Jellyfin (Dapitan Standby) | CT 510 | Dapitan | VLAN 110 (Internal) | `192.168.110.43` | 🟢 Secondary Jellyfin instance |
| | Audiobookshelf | CT 100 | Bulakan | VLAN 1 (Mgmt) | `192.168.1.59` | 🟢 Audiobook library & streaming server |
| **Photo Vault** | Immich (Primary) | CT 504 | Dapitan | VLAN 110 (Internal) | `192.168.110.47` | 🟢 Primary photo/video vault (18TB ZFS) |
| **Infrastructure & Tools** | Apache Guacamole | CT 114 | Dapitan | VLAN 110 (Internal) | `192.168.110.85` | 🟢 Clientless Remote Desktop Gateway |
| | Floci Stack | CT 512 | Dapitan | VLAN 110 (Internal) | `192.168.110.49` | 🟢 Floci development services |
| | UEFI PXE Boot Server | CT 513 | Dapitan | VLAN 110 (Internal) | `192.168.110.55` | 🟢 Network PXE OS Deployment Engine |
| | BookOrbit | CT 514 | Dapitan | VLAN 110 (Internal) | `192.168.110.50` | 🟢 E-book & library sync |
| | Calibre-Web | CT 113 | Bulakan | VLAN 1 (Mgmt) | `DHCP` | 🟢 Web e-book manager |
| | Homepage Dashboard | CT 116 | Bulakan | VLAN 1 (Mgmt) | `DHCP` | 🟢 Central homelab service portal |
| | Heimdall Dashboard | CT 115 | Bulakan | VLAN 1 (Mgmt) | `DHCP` | 🟢 Service bookmark dashboard |
| **Security & SIEM** | Wazuh SIEM | VM 250 | Cebu | VLAN 10 (SecOps) | `192.168.10.250` | 🟢 Threat detection & log analysis |
| **Workstations & Smart Home** | Linux Mint Remote Desktop | VM 505 | Dapitan | VLAN 20 (Trusted) | `DHCP` | 🟢 Management Jump Box (128GB disk) |
| | Home Assistant OS (HAOS) | VM 111 | Dapitan | VLAN 1 (Mgmt) | `192.168.1.207` | 🟢 Smart Home Automation Controller |
| | Bastion Jump Host | VM 203 | Bulakan | VLAN 1 (Mgmt) | `DHCP` | 🟢 Admin management bastion |
| **Network Storage**| Synology NAS (PNAS) | Host | Synology | VLAN 1 (Mgmt) | `192.168.1.12` | 🟢 23TB CIFS/NFS Shared PVE & Media |
| | Dapitan ZFS Bulk Storage | Host | Dapitan | VLAN 1 (Mgmt) | `192.168.1.27` | 🟢 18TB ZFS Local Dataset & Bind Mounts |

---

## 🛠️ DevOps, IaC & Automation

This repository hosts all core configuration scripts and deployment code to automate our homelab:

1. **Proxmox Sequential Update Automation Suite ([`/ansible`](ansible)):**
   - **Sequential Execution (`serial: 1`)**: Updates PVE host nodes and guest workloads strictly one at a time with cluster quorum verification (`pvecm status`).
   - **Guest Workload Protection**: Takes automated pre-update snapshots (`pct snapshot` / `qm snapshot`), executes guest package upgrades (`pct exec`), performs health checks, and triggers automated rollbacks on failure.
   - **Automated Schedule**: Programmed for **every 3rd Sunday of the month at 2:00 AM Pacific Time (`America/Los_Angeles`)** via Systemd Timer (`proxmox-update.timer`) and Crontab (`0 2 15-21 * *`).

2. **Terraform (`/terraform`):**
   - Reusable LXC container structure mapped into modules (`/terraform/proxmox/modules/lxc`).
   - Bulakan configurations are kept in `/terraform/proxmox/lxc.tf` as structural reference.
   - Cebu active modules are maintained in `/terraform/proxmox/cebu.tf` for sandbox and mirror environments.

3. **Media Automation Scripts (`/06-Guides` & `/scripts`):**
   - PowerShell scripts designed to scan, standardize, clean up, and rename media metadata across the storage pools:
     - [`animated-movies-cleanup.ps1`](06-Guides/animated-movies-cleanup.ps1): Prunes redundant metadata.
     - [`animated-movies-rename.ps1`](06-Guides/animated-movies-rename.ps1): Standardizes files to match custom anime conventions.
     - [`human-movies-standardize.ps1`](06-Guides/human-movies-standardize.ps1) & [`human-movies-deep-cleanup.ps1`](06-Guides/human-movies-deep-cleanup.ps1): Cleans and standardizes live action movie names.

---

## 📂 Vault Directory Map

Navigate our detailed documentation folders easily:

* 🖥️ **[02-Proxmox](02-Proxmox)** — Virtualization architecture, backups, failover scripts, and host tuning.
  * [Proxmox Host Overview](02-Proxmox/Proxmox%20Overview.md)
  * [Proxmox Update Automation Solutions](02-Proxmox/Proxmox-Update-Automation-Solutions.md)
  * [Rsync Sync Guide](02-Proxmox/Rsync%20Guide.md)
* 💾 **[03-Unraid (Deprecated)](03-Unraid)** — Historic NAS documentation and array logs.
  * [Unraid Legacy Overview](03-Unraid/Unraid%20Overview.md)
* 🌐 **[04-Network](04-Network)** — Gateway rules, VLAN setup, DNS settings, and routing details.
  * [Network Maps & Subnets](04-Network/Network%20Overview.md)
  * [UniFi UCG Max Setup](04-Network/UniFi%20Router%20Setup.md)
* 📁 **[04-Synology](04-Synology)** — Storage mounts, NFS configurations, and NAS backup protocols.
  * [Synology Overview & Configs](04-Synology/Synology%20Overview.md)
* 🔧 **[05-Services](05-Services)** — Configuration variables, port mappings, and settings for deployed applications.
  * [Master Services Index](05-Services/Services%20Index.md)
  * [Authentik SSO Configuration](05-Services/Authentik.md)
  * [Nginx Proxy Manager Setup](05-Services/Nginx%20Proxy%20Manager.md)
  * [Cloudflared Tunnels Configuration](05-Services/Cloudflared.md)
  * [Netbootxyz PXE Configuration](05-Services/Netbootxyz.md)
* 📖 **[06-Guides](06-Guides)** — Comprehensive operational, disaster recovery, and maintenance walk-throughs.
  * [Master Guides Index](06-Guides/Guides%20Index.md)
  * [Plex Metadata Sync & Cloning Guide](06-Guides/Plex%20Cloning%20Guide.md)
  * [Active-Active Cloudflare Tunnel Setup](06-Guides/Cloudflare-Tunnel-Setup.md)
  * [Secrets Management Best Practices](06-Guides/Homelab-Secrets-Management-Best-Practices.md)
  * [VLAN Segmentation & Firewall Roadmap](06-Guides/VLAN-Segmentation-Roadmap.md)

---

## 🚀 Getting Started & Operations

If you are setting up or managing parts of the Homelab-Net network:
1. **Adding a host/service:** Reference our [Plex Cloning Guide](06-Guides/Plex%20Cloning%20Guide.md) or [Dapitan Plex Setup](06-Guides/Dapitan-Plex-Setup-Recovery-2026-07-24.md).
2. **Accessing Consoles:** Review [How to Access Proxmox](06-Guides/How%20to%20Access%20Proxmox.md) to log in safely.
3. **Updating Hosts:** Read [Proxmox Update Automation Solutions](02-Proxmox/Proxmox-Update-Automation-Solutions.md) before pushing system patches.
