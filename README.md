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

1. **Proxmox Sequential Update Automation Suite ([`iac/ansible`](iac/ansible)):**
   - **Sequential Execution (`serial: 1`)**: Updates PVE host nodes and guest workloads strictly one at a time with cluster quorum verification (`pvecm status`).
   - **Guest Workload Protection**: Takes automated pre-update snapshots (`pct snapshot` / `qm snapshot`), executes guest package upgrades (`pct exec`), performs health checks, and triggers automated rollbacks on failure.
   - **Automated Schedule**: Programmed for **every 3rd Sunday of the month at 2:00 AM Pacific Time (`America/Los_Angeles`)** via Systemd Timer (`proxmox-update.timer`) and Crontab (`0 2 15-21 * *`).

2. **Terraform ([`iac/terraform`](iac/terraform)):**
   - Reusable LXC container structure mapped into modules (`iac/terraform/proxmox/modules/lxc`).
   - Bulakan configurations are kept in `iac/terraform/proxmox/lxc.tf` as structural reference.
   - Cebu active modules are maintained in `iac/terraform/proxmox/cebu.tf` for sandbox and mirror environments.

3. **Container Stacks ([`compose/`](compose)):**
   - [`compose/arr-stack/`](compose/arr-stack): Sonarr, Radarr, Prowlarr, Jackett, and Transmission with Gluetun WireGuard killswitch.
   - [`compose/dashboard/`](compose/dashboard): Homepage dashboard YAML configs and docker-compose.
   - [`compose/immich/`](compose/immich): Machine learning photo management stack.

4. **Media Automation Scripts ([`scripts/media-tools`](scripts/media-tools)):**
   - PowerShell and Python scripts designed to scan, standardize, clean up, and rename media metadata across the storage pools:
     - [`animated-movies-cleanup.ps1`](scripts/media-tools/animated-movies-cleanup.ps1): Prunes redundant metadata.
     - [`animated-movies-rename.ps1`](scripts/media-tools/animated-movies-rename.ps1): Standardizes files to match custom anime conventions.
     - [`human-movies-standardize.ps1`](scripts/media-tools/human-movies-standardize.ps1) & [`human-movies-deep-cleanup.ps1`](scripts/media-tools/human-movies-deep-cleanup.ps1): Cleans and standardizes live action movie names.

---

## 📂 Repository Directory Map

Navigate our structured repository:

```
homelab-infrastructure/
├── docs/                                 # 📖 Architectural documentation & operational runbooks
│   ├── architecture/                     # Cluster topology, VLAN schemas, and storage architecture
│   │   ├── cluster-topology.md           # Proxmox VE hypervisor cluster architecture
│   │   ├── network-vlan-schema.md        # 802.1Q VLAN matrix & DNS configuration
│   │   ├── storage-architecture.md       # Synology NAS & ZFS storage tiering
│   │   └── unifi-gateway-setup.md        # UniFi UCG Max routing & firewall policies
│   ├── guides/                           # Step-by-step categorized engineering runbooks
│   │   ├── media-automation/             # Arr stack, Plex GPU transcode, Jellyfin HA, metadata guides
│   │   ├── security-ingress/             # Authentik SSO, Cloudflare tunnels, NPM SSL, Wazuh SIEM
│   │   ├── hypervisor-cluster/           # PVE cluster join, UEFI PXE boot, VM optimization
│   │   └── disaster-recovery/            # DR audits, mount recoveries, storage deadlock solutions
│   └── services/                         # Service catalog & individual application deep-dives
│       ├── services-index.md             # Master services catalog & port mapping
│       ├── authentik.md                  # Central SSO & MFA configuration
│       ├── nginx-proxy-manager.md        # Reverse proxy & SSL termination
│       └── cloudflared.md                # Zero-inbound Cloudflare tunnel ingress
│
├── iac/                                  # 🏗️ Infrastructure-as-Code (Declarative)
│   ├── terraform/                        # Terraform modules & environment definitions
│   └── ansible/                          # Ansible playbooks (rolling cluster updates)
│
├── compose/                              # 🐳 Version-controlled Docker Compose templates
│   ├── arr-stack/                        # Acquisition stack with Surfshark WireGuard killswitch
│   ├── dashboard/                        # Homepage & Heimdall dashboard configs
│   └── immich/                           # Machine learning photo vault stack
│
└── scripts/                              # ⚡ Operational automation scripts
    ├── backup-replication/               # Rsync & Synology backup sync scripts
    ├── maintenance/                      # Automated update rollback & health check scripts
    └── media-tools/                      # Metadata standardization & clean-up tools
```

---

## 🚀 Getting Started & Reference Runbooks

Key foundational runbooks:
1. **SSO & Security Ingress:** [Authentik OIDC Setup Guide](docs/guides/security-ingress/Authentik-Immich-OAuth2-OIDC-Setup-Guide-2026-07-31.md) & [Cloudflare Tunnel Guide](docs/guides/security-ingress/Cloudflare-Tunnel-Setup.md).
2. **Media Stack:** [Master Arr Stack & WireGuard Setup](docs/guides/media-automation/Master-Arr-Stack-Sonarr-NPM-WireGuard-Setup-Guide-2026-08-22.md).
3. **Disaster Recovery:** [Disaster Recovery Audit](docs/guides/disaster-recovery/Disaster%20Recovery%20-%20Infrastructure%20Audit.md).
4. **Update Automation:** [Proxmox Update Automation](docs/guides/hypervisor-cluster/Proxmox-Update-Automation-Solutions.md).
