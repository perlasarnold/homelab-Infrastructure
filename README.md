# 🏠 Homelab-Net / Core Homelab Vault

[![PVE Version](https://img.shields.io/badge/Proxmox_VE-8.4.18-orange?logo=proxmox&logoColor=white&style=flat-square)](https://www.proxmox.com)
[![Status](https://img.shields.io/badge/Cluster_Status-🟢_Active-success?style=flat-square)](#)
[![Infrastructure](https://img.shields.io/badge/Infrastructure-Hybrid_IaC-blue?logo=terraform&logoColor=white&style=flat-square)](#)
[![Secrets](https://img.shields.io/badge/Secrets_Policy-Strictly_Encrypted-red?style=flat-square)](#)

Welcome to the **Homelab-Net / Core Homelab and Documentation Vault**. This repository acts as the complete operational "brain" for our home server network, written to ensure that the entire environment is fully transparent, reproducible, and easily maintainable.

> [!WARNING]
> **SECRETS POLICY:** Strictly **no plain-text passwords, private keys, API tokens, or credentials** are allowed in this vault. All infrastructure secrets must be handled through Authentik (SSO) or local credentials files excluded from Git.

---

## 🗺️ Cluster Topology & Network Segmentation

Our infrastructure is architected as a resilient, multi-node **Proxmox Virtual Environment** cluster connected with high-speed local storage tiers, shared Synology NAS storage, bulk ZFS arrays, and an automated media/compute stack isolated across 802.1Q VLANs.

```
                      ┌─────────────────────────────────┐
                      │      UniFi UCG Max Gateway      │  (gateway.homelab.internal)
                      │       [VLAN 1 Management]       │
                      └────────────────┬────────────────┘
                                       │
                ┌──────────────────────┼──────────────────────┐
                ▼                      ▼                      ▼
    ┌──────────────────────┐ ┌──────────────────────┐ ┌──────────────────────┐
    │   Proxmox BULAKAN    │ │     Proxmox CEBU     │ │   Proxmox DAPITAN    │
    │  (Primary Hypervisor)│ │ (Secondary Hypervisor)│ │(Bulk Storage / Media)│
    │  [VLAN 1 Management] │ │  [VLAN 1 Management] │ │  [VLAN 1 Management] │
    └───────────┬──────────┘ └───────────┬──────────┘ └───────────┬──────────┘
                │                        │                        │
                ├─► LXC Containers       ├─► LXC Containers       ├─► 18TB ZFS Direct Mount
                │   (Plex, Jellyfin,     │   (Authentik SSO, NPM, │   (/mnt/bindmounts)
                │    Cloudflared, PiHole)│    Arr Stack, Wazuh)   │   (Immich, Plex,
                │                        │                        │    Jellyfin, PXE)
                └─► VMs (Win10 Bastion)  └─► VMs (Wazuh SIEM)     └─► VMs (HAOS, Mint Jump)
                ┌─────────────────────────────────────────────────────────────┐
                │                  Active Network Storage                     │
                │  1. PNAS Synology (nas.homelab.internal) ── VLAN 1 [Storage]│
                │  2. Dapitan ZFS (dapitan.homelab.internal) ── 18TB ZFS Bulk │
                └─────────────────────────────────────────────────────────────┘
```

---

## 🖥️ Core Infrastructure Nodes

### 1. Proxmox Bulakan (`bulakan.homelab.internal` — `VLAN 1 [Management]`)
* **Hardware & OS:** Intel Core i5-9500T (6 Cores) | 32GB RAM | PVE 9.2.5
* **Network Redundancy:** Active-Backup Bond (`bond0`) combining onboard Intel NIC (`enp1s0`) and a backup USB Realtek NIC (`enx000000000000`) to ensure zero-downtime path failover.
* **Storage Pools:** `Bulakan-ZFS` (2TB SSD ZFS pool) + mounted Synology storage.
* **Role:** Primary Hypervisor Node. Runs core services, secondary DNS, and primary media orchestration. Bulakan containers are managed manually using helper scripts to ensure high runtime stability.

### 2. Proxmox Cebu (`cebu.homelab.internal` — `VLAN 1 [Management]`)
* **Hardware & Storage:** Local `cebu-zfs` pool (2TB SSD) | Mounted Synology shares (`PNAS-Seagate`).
* **Role:** Secondary Hypervisor & Ingress Gateway. Hosts central identity provider (Authentik SSO), primary reverse proxy (Nginx Proxy Manager), and SIEM threat intelligence.

### 3. Proxmox Dapitan (`dapitan.homelab.internal` — `VLAN 1 [Management]`)
* **Hardware & Storage:** Dell OptiPlex 7050 SFF | Intel Core i5-7500 | 40 GiB RAM | 1TB NVMe `vm-fast` + 18TB Seagate IronWolf ZFS `bulk18`.
* **Storage Shares:** Local direct bind mounts at `/mnt/bindmounts/media-data`, `/mnt/bindmounts/immich-data`, `/mnt/bindmounts/floci-data`, and `/mnt/bindmounts/shared`.
* **Role:** Bulk media, machine learning, and photo application node hosting Immich, Plex DP, Jellyfin DP, Guacamole, and PXE deployment services.

### 4. Synology NAS (`nas.homelab.internal` — `VLAN 1 [Management]`)
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

### 🔐 Identity, Ingress & Security
| Service | Host & ID | VLAN | Architectural Function |
|:---|:---:|:---:|:---|
| **Authentik SSO** | Cebu `CT 103` | VLAN 110 | Central Identity Provider, MFA & OIDC (`HTTPS: 443`) |
| **Nginx Proxy Manager** | Cebu `CT 105` | VLAN 120 | Primary Ingress Reverse Proxy with Wildcard Let's Encrypt SSL |
| **Nginx Proxy Manager** | Bulakan `CT 102` | VLAN 120 | Standby Cold Failover Reverse Proxy (Stopped) |
| **Cloudflared Tunnel** | Bulakan `CT 304` | VLAN 120 | Primary Zero-Inbound Cloudflare Edge Ingress Tunnel |
| **Cloudflared Tunnel** | Cebu `CT 404` | VLAN 120 | Redundant Active Zero-Inbound Cloudflare Edge Tunnel |
| **Pi-hole DNS (Primary)** | Bulakan `CT 301` | VLAN 1 | Core DNS Ad-blocker & Split-Horizon Local Domain Resolver |
| **Pi-hole DNS (Secondary)**| Cebu `CT 401` | VLAN 1 | High-Availability Mirrored DNS Failover Resolver |
| **Wazuh SIEM & XDR** | Cebu `VM 250` | VLAN 10 | Security Threat Analytics, Host Integrity & Event Management |

### 🎬 Media Streaming & Automation
| Service | Host & ID | VLAN | Architectural Function |
|:---|:---:|:---:|:---|
| **Consolidated Arr Stack** | Cebu `CT 417` | VLAN 110 | Sonarr/Radarr/Prowlarr/Transmission with Surfshark WireGuard Killswitch |
| **Plex Media Server** | Bulakan `CT 104` | VLAN 1 | Primary Media Server with Intel 9th Gen QuickSync GPU & RAM Transcode |
| **Plex Media Server** | Dapitan `CT 509` | VLAN 110 | Bulk Media Server with 18TB Direct ZFS Storage Mount |
| **Jellyfin Media Server** | Bulakan `CT 110` | VLAN 110 | Primary Jellyfin Server with Intel GPU Passthrough |
| **Jellyfin (Standby)** | Cebu `CT 416` | VLAN 110 | Failover Jellyfin Container for High-Availability |
| **Jellyfin (Bulk)** | Dapitan `CT 510` | VLAN 110 | Secondary Jellyfin Server with 18TB Direct ZFS Mount |
| **Audiobookshelf** | Bulakan `CT 100` | VLAN 1 | Self-hosted Audiobook & Podcast Streaming Server (`Port: 13378`) |

### 📁 Storage, Tools & Workstations
| Service | Host & ID | VLAN | Architectural Function |
|:---|:---:|:---:|:---|
| **Immich Photo Vault** | Dapitan `CT 504` | VLAN 110 | High-Performance ML Photo/Video Backup on 18TB ZFS Storage |
| **Apache Guacamole** | Dapitan `CT 114` | VLAN 110 | Clientless HTML5 Remote Desktop Gateway (RDP, VNC, SSH) |
| **UEFI PXE Boot Server** | Dapitan `CT 513` | VLAN 110 | Automated OS Network Deployment Engine |
| **BookOrbit / Calibre** | Dapitan `CT 514` | VLAN 110 | E-book Library Management & Multi-Format Reader |
| **Homepage Portal** | Bulakan `CT 116` | VLAN 1 | Central Unified Homelab Status & Dashboard Portal |
| **Linux Mint Desktop** | Dapitan `VM 505` | VLAN 20 | Isolated Remote Management Workstation (128GB Fast Storage) |
| **Home Assistant (HAOS)** | Dapitan `VM 111` | VLAN 1 | Smart Home Automation Controller |
| **Synology PNAS** | Synology Host | VLAN 1 | 23TB High-Availability CIFS/NFS Shared Storage Pool |
| **Dapitan 18TB ZFS** | Dapitan Host | VLAN 1 | Direct-Attached IronWolf ZFS Bulk Storage Pool |

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
homelab/
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

## 🚀 Getting Started & Operations

If you are setting up or managing parts of the Homelab-Net network:
1. **Adding a host/service:** Reference our [Plex Cloning Guide](06-Guides/Plex%20Cloning%20Guide.md) or [Dapitan Plex Setup](06-Guides/Dapitan-Plex-Setup-Recovery-2026-07-24.md).
2. **Accessing Consoles:** Review [How to Access Proxmox](06-Guides/How%20to%20Access%20Proxmox.md) to log in safely.
3. **Updating Hosts:** Read [Proxmox Update Automation Solutions](02-Proxmox/Proxmox-Update-Automation-Solutions.md) before pushing system patches.
