# 📦 Unraid Overview

> **Host IP:** `VLAN 1 (Management)` | **Server Name:** Mercado  
> **Web UI:** https://VLAN 1 (Management) | **Unraid Version:** 7.2.4  
> **Last Updated:** 2026-04-12 | **Maintainer:** Perlas  
> **Status:** Production | **Reproducibility Score:** 8/10 (See Scalability Section)

---

## What is Unraid?

Unraid is a **NAS (Network Attached Storage) operating system** that also runs Docker containers and VMs. It uses a parity-based storage system — you can mix drives of different sizes and if one data drive fails, parity protects your data.

---

## Host Hardware & Array

| Role | Drive | Size | FS | Notes |
|------|-------|------|----|-------|
| Parity | ST18000NT001 | 18 TB | — | Data protection |
| Disk 1 | ST18000NT001 | 18 TB | xfs | ~9 TB used |
| Disk 2 | ST18000NT001 | 18 TB | xfs | ~8.5 TB used |
| Disk 3 | WDC WD60EFAX | 6 TB | xfs | ~42 GB used |
| Cache | TEAM T2532TB | 2 TB | btrfs | SSD fast cache |
| Boot | SanDisk Cruzer | 8 GB | — | USB flash drive |

**Total usable array:** ~42 TB | **Used:** ~17.5 TB

---

## Network Shares

| Share | Use | Cache Policy |
|-------|-----|-------------|
| appdata | Docker app config data | Cache+Array |
| Documents | Personal documents | Cache→Array |
| domains | VM disk images | Cache←Array |
| downloads | Temporary download staging | Cache only |
| isos | OS ISO images | Cache→Array |
| media | General media storage | Cache only |
| Photos | Photography archive (NFS) | Array only |
| PlexMedia | Plex/Jellyfin libraries | Cache→Array |
| system | Unraid system files | Cache←Array |

---

## Docker Containers — Running

| Container | Network | Host Port(s) | Purpose |
|-----------|---------|------------|---------|
| audiobookshelf | bridge | 13378 | Audiobook & podcast server |
| binhex-official-pihole | macvlan br0 | VLAN 1 (Management) | DNS ad-blocker |
| heimdall | bridge | 8088 | Application dashboard |
| Jellyfin | host | 8096 | Open-source media server |
| MariaDB-Official | bridge | 3306 | MySQL-compatible database |
| NginxProxyManager | bridge | 18443 / 1880 / 7818 | Reverse proxy + SSL |
| Plex-Media-Server | host | 32400 | Plex media server |
| Unraid-Cloudflared-Tunnel | bridge | — | Cloudflare Zero Trust tunnel |

## Docker Containers — Stopped

| Container | Purpose |
|-----------|---------|
| macinabox | macOS Docker VM |
| PostgreSQL_Immich | Postgres for Immich |
| Immich (Compose) | Self-hosted photo management |

---

## Installed Plugins

| Plugin | Purpose |
|--------|---------|
| Community Applications | Unraid app marketplace |
| Compose Manager | Docker Compose stack management |
| Appdata Backup | Automated appdata backups |
| CA Auto Update Applications | Auto-update containers |
| User Scripts | Custom script runner |
| User Scripts Enhanced | UI improvements for scripts |
| Unassigned Devices | Manage disks outside array |
| RTL8152 Drivers | Realtek USB NIC drivers |

---

## Terraform

All containers above are codified in Terraform:

```
terraform/unraid/
├── main.tf          ← provider (kreuzwerker/docker ~> 3.0)
├── variables.tf     ← unraid_ip, paths
├── containers.tf    ← all 10 Docker containers
└── outputs.tf       ← service URLs
```

To import existing containers: `.\terraform\import.ps1 -Module unraid`

> **Note:** Requires Docker TCP API enabled on Unraid, or an SSH tunnel.

---

## Related Pages

- [[04-Network/Network Overview]] — full network map
- [[05-Services/Services Index]] — all service URLs

---

## Scalability & Reproducibility

### Current State
All Unraid Docker containers are managed via Terraform in `terraform/unraid/`. The current setup achieves approximately 8/10 reproducibility.

### Areas for Improvement

#### 1. Variable Standardization
- **Current**: Some values hardcoded in `containers.tf`
- **Target**: Move all configurable values to `variables.tf` with sensible defaults
- **Example**: Container ports, volumes, environment variables should be variables

#### 2. Module Structure
- **Current**: Single directory with multiple `.tf` files
- **Target**: Create reusable modules for common patterns (e.g., `modules/unraid-container`, `modules/unraid-network`)
- **Benefit**: Enable easy duplication for new Unraid servers or environments

#### 3. Secrets Management
- **Current**: Some secrets may be in plain text or docker-compose files
- **Target**: Integrate with HashiCorp Vault or use Docker secrets
- **Intermediate**: Use `.tfvars` files excluded from git with example templates

#### 4. Validation & Testing
- **Current**: Manual validation through `terraform plan`
- **Target**: Implement automated validation:
  - `terraform validate` in CI pipeline
  - Configuration testing with container structure tests
  - Pre-commit hooks for formatting (terraform fmt)

#### 5. Documentation Automation
- **Current**: Manual documentation updates
- **Target**: Generate documentation from Terraform:
  - Use `terraform-docs` to generate inputs/outputs documentation
  - Auto-update Overview.md with current container counts and status

### Reproducibility Checklist for New Devices
When setting up a new Unraid server:

1. [ ] Install Unraid OS (match major version)
2. [ ] Configure network settings (match IP scheme or update variables)
3. [ ] Set up storage array and cache drives (adjust variables if needed)
4. [ ] Enable Docker TCP API OR set up SSH tunnel (see Terraform prerequisites)
5. [ ] Update `terraform.tfvars` with server-specific values
6. [ ] Run `terraform init` and `terraform apply`
7. [ ] Verify all containers start correctly and are accessible
8. [ ] Update documentation with new server details

### Next Steps
1. Refactor Terraform to use modules
2. Implement variable-driven container configuration
3. Add secrets management integration
4. Create automated documentation generation
5. Set up validation pipeline
