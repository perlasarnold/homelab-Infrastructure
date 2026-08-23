# 🖥️ Proxmox Overview

> **Cluster:** Homelab-Net | **Nodes:** Bulakan (`192.168.1.25`), Cebu (`192.168.1.26`), Dapitan (`192.168.1.27`)
> **PVE Versions:** Bulakan 9.2.5 | Cebu 9.2.5 | Dapitan 9.2.5 | **Last Updated:** 2026-07-23 | **Maintainer:** Perlas  
> **Status:** Production / Clustered (ZFS Replication Active) | **Reproducibility Score:** 10/10

### Bulakan (192.168.1.25)
- **CPU**: Host | **RAM**: 32GB+
- **PVE**: 9.2.5 | **Kernel**: 7.0.14-6-pve
- **Storage**: 
    - `Bulakan-ZFS` (2TB) — Primary Local ZFS Pool (NVMe/SSD)
    - `PNAS` (23TB SMB/CIFS) — Shared Synology NAS Storage
- **Role**: Primary Node / Replication Source

### Cebu (192.168.1.26)
- **PVE**: 9.2.5 | **Kernel**: 7.0.14-6-pve
- **Update status**: Managed via automated Ansible maintenance cycles with pre-update snapshot validation
- **Storage**: 
    - `cebu-zfs` (2TB SSD) — Local ZFS Pool
- **Network**:
    - `vmbr0` → `nic0` (192.168.1.26) — **Active Bridge**
    - `eth0` (192.168.1.41) — Auxiliary Interface
    - `vnet1` — SDN Isolated VXLAN Bridge
    - `PNAS` (23TB SMB/CIFS) — Shared Synology NAS Storage
    - `PNAS-Seagate` (7.3TB SMB/CIFS) — Mounted at `/mnt/pve/PNAS-Seagate`
    - DAS JBOD (3x18TB + 6TB) — **Offline/powered down 2026-07-22**; Proxmox storage entries `DAS1`-`DAS4` and `DAS4-Backups` disabled
    - Known warning: stale systemd import units for the four retired DAS pools fail at boot; active `cebu-zfs` remains healthy
- **Role**: Backup Node / Replication Target / Replacement for Mercado (Unraid)
- **Sync Workflow**: Synology (`Seagate`) ➡️ Cebu (`das-18tb-1`) via [Rsync Guide](./Rsync%20Guide.md)

### Dapitan (192.168.1.27)
- **Hardware**: Dell OptiPlex 7050 SFF | Intel Core i5-7500 | 40 GiB RAM
- **PVE**: 9.2.5 | **Kernel**: 7.0.14-6-pve
- **Cluster status**: Joined `Homelab-Net` as node 3 on 2026-07-23; quorum is 2-of-3
- **Storage**:
    - `vm-fast` — Samsung 870 QVO 1 TB ZFS pool for VM/LXC disks; restricted to Dapitan
    - `bulk18` — Seagate IronWolf Pro 18 TB host-managed ZFS pool for media, Immich, and shared data
    - `PNAS` — Shared Synology SMB/CIFS storage, active on Dapitan
- **Bulk mounts**:
    - `/mnt/bindmounts/shared`
    - `/mnt/bindmounts/media-data`
    - `/mnt/bindmounts/immich-data`
    - `/mnt/bindmounts/floci-data`
- **Role**: Media/application replacement node with direct-attached bulk storage
- **Guide**: [Dapitan Homelab-Net Cluster Join](../06-Guides/Dapitan-Homelab-Net-Cluster-Join-2026-07-23.md)

---

## What is Proxmox?

Proxmox Virtual Environment is an open-source **hypervisor** — it lets you run multiple virtual machines (VMs) and lightweight Linux containers (LXC) on a single physical server.

- **VMs** = full virtual computers (can run Windows, Linux, macOS)
- **LXC Containers** = lightweight Linux environments, faster and lower overhead than VMs

---

## Host Hardware

| Component | Details |
|-----------|---------|
| CPU | Intel Core i5-9500T @ 2.20GHz (6 cores) |
| RAM | 31.16 GiB total (~29 GiB used) |
| Kernel | Linux 7.0.14-6-pve |
| Boot Drive | Local directory `/var/lib/vz` |
| PVE Version | 9.2.5 |

---

## Storage Pools

| Name | Type | Content |
|------|------|---------|
| Bulakan-ZFS | ZFS | Disk images, Containers |
| PNAS | SMB/CIFS (Synology) | Backups, ISOs, Templates |
| local | Directory `/var/lib/vz` | Backups, ISOs, Templates |
| local-lvm | LVM-Thin | Disk images, Containers |

---

## Network Configuration

| Interface | Type | IP / Detail |
|-----------|------|-------------|
| vmbr0 | Linux Bridge | 192.168.1.25/24 — main LAN bridge |
| bond0 | Active-Backup Bond | enp1s0 (onboard) + enx000000000000 (USB NIC) |
| vmbr1 | Linux Bridge | Unpopulated (reserved) |

---

## LXC Containers — Running

| ID | Name | CPU | RAM | IP | Purpose |
|----|------|-----|-----|----|---------|
| 100 | audiobookshelf | 2 | 2 GiB | 192.168.1.59 | Audiobook server |
| 101 | wireguard | 1 | 512 MiB | DHCP | WireGuard VPN gateway |
| 104 | plex | 4 | 4 GiB | 192.168.1.54 | Plex Media Server (Bulakan, 9th Gen QSV GPU, RAM Transcode) |
| 109 | plex-cebu | 4 | 4 GiB | 192.168.1.215 | Plex Media Server (Cebu, 10th Gen QSV GPU, RAM Transcode) |
| 509 | plex-dapitan | 4 | 4 GiB | 192.168.110.44 | Plex Media Server (Dapitan, QSV GPU, 18TB ZFS, RAM Transcode) |
| 107 | bazarr | 2 | 1 GiB | 192.168.1.137 | Subtitle manager |
| 108 | jackett | 1 | 512 MiB | 192.168.1.58 | Tracker indexer proxy |
| 110 | jellyfin | 2 | 4 GiB | 192.168.110.41 | Jellyfin media server (Bulakan, QSV GPU) |
| 416 | jellyfin-cebu | 4 | 4 GiB | 192.168.110.42 | Jellyfin media server (Cebu, 10th Gen QSV GPU) |
| 510 | jellyfin-dapitan | 4 | 4 GiB | 192.168.110.43 | Jellyfin media server (Dapitan, QSV GPU, 18TB ZFS Direct, RAM Transcode) |
| 511 | photoview-dapitan | 2 | 2 GiB | 192.168.110.48 | Photoview photo gallery engine |
| 512 | floci-dapitan | 4 | 4 GiB | 192.168.110.49 | Floci multi-cloud stack (AWS 4566, AZ 4577, GCP 4588, UI 4500) |
| 513 | pxe-dapitan | 2 | 2 GiB | 192.168.110.55 | UEFI/BIOS PXE Boot, TFTP & HTTP Kickstart Server (`pxe.homelab-admin.me`) |
| 111 | photoprism | 2 | 4 GiB | DHCP | AI photo library |
| 112 | transmission | 2 | 2 GiB | DHCP | BitTorrent client |
| 115 | heimdall-dashboard | 1 | 512 MiB | DHCP | App dashboard |
| 118 | netbootxyz | 2 | 1 GiB | DHCP | PXE network boot server |
| 301 | piHole | 2 | 512 MiB | 192.168.1.4 | DNS ad-blocker |
| 304 | cloudflared | 2 | 1 GiB | 192.168.1.6 | Cloudflare tunnel |


---

---

## Virtual Machines — Running

### Bulakan Node (Primary)
| ID | Name | CPU | RAM | Disk | OS | Purpose |
|----|------|-----|-----|------|----|---------|
| 201 | Perlas-W10 | 4 | 8 GiB | 60 GiB | Windows 10 | Daily-use Windows desktop |
| 204 | Immich-UbuntuLTS | 4 | 12 GiB | 600 GiB | Ubuntu LTS | Immich photo management |

### Cebu Node (Backup / Replacement)
| ID | Name | CPU | RAM | Disk | OS | Purpose |
|----|------|-----|-----|------|----|---------|
| 101 | Perlas-W10 | 4 (host) | 12 GiB | 200 GiB | Windows 10 | Daily-use Windows desktop (Cebu) |
| 111 | haos-17.3 | 2 (host) | 4 GiB | 32 GiB | HAOS | Home Assistant OS (Cebu) |
| 120 | truenas | - | - | - | TrueNAS SCALE | **Decommissioned & Removed** |

---

---

## Terraform & Infrastructure Management
 
### Current Strategy (As of 2026-05-14)
> [!WARNING]
> **Terraform management for the Bulakan node has been DEPRECATED.**
> Due to reliability issues with the Proxmox provider creating "broken" LXC containers on the primary node, management has shifted to a hybrid model.

- **Bulakan**: Manual Management (Tteck Proxmox Helper Scripts) + Static Documentation.
- **Cebu**: Testing ground for Terraform modules (Active-Active Mirroring).
- **Goal**: Maintain code-visibility in Terraform for reference, but use manual provisioning for production stability on the primary node.

### File Structure
```
terraform/proxmox/
├── modules/
│   └── lxc/       ← Reusable LXC module
├── main.tf        ← Provider configuration
├── variables.tf   ← Multi-node variables
├── lxc.tf         ← Bulakan LXC definitions (REFERENCE ONLY)
├── cebu.tf        ← Cebu LXC definitions (ACTIVE)
├── vms.tf         ← Bulakan VMs (REFERENCE ONLY)
└── outputs.tf
```

To import existing resources if re-adopting Terraform: `.\terraform\import.ps1 -Module proxmox`

---


## Related Pages

- [[04-Network/Network Overview]] — full network map
- [[05-Services/Services Index]] — service URLs

---

## Scalability & Reproducibility

### Current State
All Proxmox resources (LXC containers and VMs) are managed via Terraform in `terraform/proxmox/`. The current setup achieves approximately 9/10 reproducibility.

### Areas for Improvement

#### 1. Variable Standardization
- **Current**: Some values hardcoded in `lxc.tf` and `vms.tf`
- **Target**: Move all configurable values to `variables.tf` with sensible defaults
- **Example**: Container RAM, CPU, disk sizes should be variables

#### 2. Module Structure
- **Status**: [COMPLETED 2026-05-14] Created `modules/proxmox-lxc`
- **Benefit**: Enabled easy duplication for the `Cebu` node.

#### 3. Secrets Management
- **Current**: API token stored as plain variable (marked sensitive)
- **Target**: Integrate with HashiCorp Vault or AWS Secrets Manager
- **Intermediate**: Use `.tfvars` files excluded from git with example templates

#### 4. Validation & Testing
- **Current**: Manual validation through `terraform plan`
- **Target**: Implement automated validation:
  - `terraform validate` in CI pipeline
  - Configuration testing with tools like Terratest
  - Pre-commit hooks for formatting (terraform fmt)

#### 5. Documentation Automation
- **Current**: Manual documentation updates
- **Target**: Generate documentation from Terraform:
  - Use `terraform-docs` to generate inputs/outputs documentation
  - Auto-update Overview.md with current resource counts

### Reproducibility Checklist for New Devices
When setting up a new Proxmox node:

1. [ ] Install Proxmox VE (match major version)
2. [ ] Configure network interfaces (adjust vmbr0/bond0 as needed)
3. [ ] Create storage pools (match names or update variables)
4. [ ] Generate API token with appropriate permissions
5. [ ] Update `terraform.tfvars` with node-specific values
6. [ ] Run `terraform init` and `terraform apply`
7. [ ] Verify all containers/VMs start correctly
8. [ ] Update documentation with new node details

### Next Steps
1. Refactor Terraform to use modules
2. Implement variable-driven resource sizing
3. Add secrets management integration
4. Create automated documentation generation
5. Set up validation pipeline


Added 04202026
proxmox 
Permissions/API
Secret key/Terraform
a858c124-85f3-4ab1-8d76-bfb1aa24920d
