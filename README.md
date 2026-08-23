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

Our homelab is architected as a resilient, multi-node **Proxmox Virtual Environment** cluster connected with high-speed local storage, shared Synology NAS storage, bulk ZFS storage tiers, and an automated media/compute stack isolated across 802.1Q VLANs.

```
                      ┌─────────────────────────────────┐
                      │      UniFi UCG Max Gateway      │  (VLAN 1 Management & Routing)
                      └────────────────┬────────────────┘
                                       │
                ┌──────────────────────┼──────────────────────┐
                ▼                      ▼                      ▼
    ┌──────────────────────┐ ┌──────────────────────┐ ┌──────────────────────┐
    │   Proxmox BULAKAN    │ │     Proxmox CEBU     │ │   Proxmox DAPITAN    │
    │   (Primary Hypervisor)│ │  (Secondary Hypervisor)│ │  (Bulk Storage / Media) │
    │   VLAN 1 [Management]│ │   VLAN 1 [Management]│ │   VLAN 1 [Management]│
    └───────────┬──────────┘ └───────────┬──────────┘ └───────────┬──────────┘
                │                        │                        │
                ├─► LXC (VLAN 110/120/1) ├─► LXC (VLAN 110/120/1) ├─► 18TB ZFS Direct Mount
                │   (Plex, Jellyfin,     │   (Authentik SSO, NPM, │   (/mnt/bindmounts)
                │    Cloudflared, PiHole)│    Arr Stack, Wazuh)   │   (Immich, Plex,
                │                        │                        │    Jellyfin, PXE)
                └─► VMs (Win10 Bastion)  └─► VMs (Wazuh SIEM)     └─► VMs (HAOS, Mint Jump Box)
                ┌─────────────────────────────────────────────────────────────┐
                │                  Active Network Storage                     │
                │  1. PNAS Synology (VLAN 1 [Management]) ── Shared PVE Storage│
                │  2. Dapitan ZFS Pool (VLAN 1 [Management]) ── 18TB ZFS Bulk │
                └─────────────────────────────────────────────────────────────┘
```

---

## 🖥️ Core Infrastructure Nodes

### 1. Proxmox Bulakan (`VLAN 1 [Management]`)
* **Hardware & OS:** Intel Core i5-9500T (6 Cores) | 32GB RAM | PVE 9.2.5
* **Network Redundancy:** Active-Backup Bond (`bond0`) combining onboard Intel NIC (`enp1s0`) and a backup USB Realtek NIC (`enx000000000000`) to ensure zero-downtime path failover.
* **Storage Pools:** `Bulakan-ZFS` (2TB SSD ZFS pool) + mounted Synology storage.
* **Role:** Primary Hypervisor Node. Runs core services, secondary DNS, and primary media orchestration. Bulakan containers are managed manually using helper scripts to ensure high runtime stability.

### 2. Proxmox Cebu (`VLAN 1 [Management]`)
* **Hardware & Storage:** Local `cebu-zfs` pool (2TB SSD) | Mounted Synology shares (`PNAS-Seagate`).
* **Role:** Secondary Hypervisor & Ingress Gateway. Hosts central identity provider (Authentik SSO), primary reverse proxy (Nginx Proxy Manager), and SIEM threat intelligence.

### 3. Proxmox Dapitan (`VLAN 1 [Management]`)
* **Hardware & Storage:** Dell OptiPlex 7050 SFF | Intel Core i5-7500 | 40 GiB RAM | 1TB NVMe `vm-fast` + 18TB Seagate IronWolf ZFS `bulk18`.
* **Storage Shares:** Local direct bind mounts at `/mnt/bindmounts/media-data`, `/mnt/bindmounts/immich-data`, `/mnt/bindmounts/floci-data`, and `/mnt/bindmounts/shared`.
* **Role:** Bulk media, machine learning, and photo application node hosting Immich, Plex DP, Jellyfin DP, Guacamole, and PXE deployment services.

### 4. Synology NAS (`VLAN 1 [Management]`)
* **Active Storage:** `PNAS` (23TB CIFS/SMB) serving as shared storage for VM backups, ISO templates, and shared application files.
* **Backup Sync:** Synology `Seagate` shares are backed up across nodes using custom-scheduled Rsync transfers.

---

## 🌐 Network Segmentation & Security

* **Gateway:** UniFi Cloud Gateway Max managing stateful firewall inspection and inter-VLAN routing rules.
* **VLAN Layout:**
  * **VLAN 1 (Management):** Dedicated to trusted hypervisor hosts, switches, and core infrastructure management interfaces.
  * **VLAN 10 (Security & SIEM):** Isolated security operations network hosting Wazuh SIEM and threat analysis engines.
  * **VLAN 20 (Trusted Workstations):** Secure network for administrative jump boxes and daily workstations.
  * **VLAN 110 (Internal Services):** Private application segment for media streaming, databases, identity providers, and background services.
  * **VLAN 120 (DMZ / External Ingress):** Dedicated public ingress network for Nginx Proxy Manager and Cloudflare Tunnels (no inbound router ports required).

---

## 🔧 Master Service Catalog

All containerized and virtualized services mapped by hypervisor node, network segment, and functional role:

| Category | Service Name | ID | Host Node | Network / VLAN Segment | Port / Ingress | Architecture & Security Controls |
|:---|:---|:---:|:---:|:---:|:---:|:---|
| **Identity & SSO** | Authentik | CT 103 | Cebu | VLAN 110 (Services) | HTTPS / 443 | 🟢 Central SSO, MFA & OAuth2/OIDC Provider |
| **Reverse Proxy** | Nginx Proxy Manager (Primary) | CT 105 | Cebu | VLAN 120 (DMZ) | HTTP: 80 / HTTPS: 443 | 🟢 Active Ingress Controller with Wildcard Let's Encrypt SSL |
| | Nginx Proxy Manager (Standby) | CT 102 | Bulakan | VLAN 120 (DMZ) | HTTP: 80 / HTTPS: 443 | ⚪ Standby Cold Failover Proxy (Stopped) |
| **Ingress Tunnels**| Cloudflared (Bulakan) | CT 304 | Bulakan | VLAN 120 (DMZ) | Encrypted Edge Tunnel | 🟢 Zero-Inbound Cloudflare Tunnel Ingress |
| | Cloudflared (Cebu) | CT 404 | Cebu | VLAN 120 (DMZ) | Encrypted Edge Tunnel | 🟢 Redundant Active Zero-Inbound Tunnel |
| **Core DNS** | Pi-hole (Primary) | CT 301 | Bulakan | VLAN 1 (Management) | DNS: 53 | 🟢 Primary DNS Ad-blocker & Split-Horizon Resolver |
| | Pi-hole (Secondary) | CT 401 | Cebu | VLAN 1 (Management) | DNS: 53 | 🟢 Secondary Mirrored High-Availability DNS Resolver |
| **Arr Stack** | Arr Stack (Sonarr/Radarr/Prowlarr/Transmission/Jackett/Bazarr) | CT 417 | Cebu | VLAN 110 (Services) | Web: 8989, 7878, 9696, 9091 | 🟢 Complete Acquisition Stack with Surfshark WireGuard Killswitch |
| **Media Servers** | Plex Media Server (Primary) | CT 104 | Bulakan | VLAN 1 (Management) | Web: 32400 | 🟢 Intel 9th Gen QuickSync GPU & RAM Transcoding |
| | Plex Media Server (Dapitan) | CT 509 | Dapitan | VLAN 110 (Services) | Web: 32400 | 🟢 Direct 18TB ZFS Storage Mount & GPU Acceleration |
| | Jellyfin (Primary) | CT 110 | Bulakan | VLAN 110 (Services) | Web: 8096 | 🟢 Primary Jellyfin Instance with Intel GPU Passthrough |
| | Jellyfin (Cebu Standby) | CT 416 | Cebu | VLAN 110 (Services) | Web: 8096 | 🟢 Cold Failover Jellyfin Container |
| | Jellyfin (Dapitan Standby) | CT 510 | Dapitan | VLAN 110 (Services) | Web: 8096 | 🟢 Secondary Jellyfin Instance (18TB ZFS Direct) |
| | Audiobookshelf | CT 100 | Bulakan | VLAN 1 (Management) | Web: 13378 | 🟢 Self-hosted Audiobook & Podcast Streaming |
| **Photo Vault** | Immich (Primary) | CT 504 | Dapitan | VLAN 110 (Services) | Web: 2283 | 🟢 High-Performance Machine Learning Vault (18TB ZFS) |
| **Infrastructure & Tools** | Apache Guacamole | CT 114 | Dapitan | VLAN 110 (Services) | Web: 8080 | 🟢 Clientless HTML5 Remote Desktop Gateway (RDP/VNC/SSH) |
| | Floci Stack | CT 512 | Dapitan | VLAN 110 (Services) | Ports: 4566, 4577, 4588 | 🟢 Multi-Cloud Emulation & Local Sandbox |
| | UEFI PXE Boot Server | CT 513 | Dapitan | VLAN 110 (Services) | TFTP / HTTP: 80 | 🟢 Automated OS Network Deployment Engine |
| | BookOrbit | CT 514 | Dapitan | VLAN 110 (Services) | Web: 3000 | 🟢 Modern E-book Library & Reader |
| | Calibre-Web | CT 113 | Bulakan | VLAN 1 (Management) | Web: 8083 | 🟢 E-book Organization & Synology Mount |
| | Homepage Dashboard | CT 116 | Bulakan | VLAN 1 (Management) | Web: 3000 | 🟢 Unified Modern Service Status Portal |
| | Heimdall Dashboard | CT 115 | Bulakan | VLAN 1 (Management) | Web: 80 | 🟢 Application Quick-Access Launchpad |
| **Security & SIEM** | Wazuh SIEM | VM 250 | Cebu | VLAN 10 (SecOps) | Agent: 1514 / Web: 443 | 🟢 Real-time Threat Detection, File Integrity & SIEM |
| **Workstations & Smart Home** | Linux Mint Remote Desktop | VM 505 | Dapitan | VLAN 20 (Trusted) | CRD / RDP | 🟢 Isolated Jump Box (128GB NVMe Fast Storage) |
| | Home Assistant OS (HAOS) | VM 111 | Dapitan | VLAN 1 (Management) | Web: 8123 | 🟢 Smart Home Automation Controller |
| | Bastion Jump Host | VM 203 | Bulakan | VLAN 1 (Management) | SSH: 22 | 🟢 Administrative SSH Management Bastion |
| **Network Storage**| Synology NAS (PNAS) | Host | Synology | VLAN 1 (Management) | SMB / NFS | 🟢 23TB High-Availability CIFS/NFS Shared Cluster Pool |
| | Dapitan ZFS Bulk Storage | Host | Dapitan | VLAN 1 (Management) | ZFS Datasets | 🟢 18TB IronWolf Direct-Attached Storage Pool |

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
