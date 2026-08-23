# 🏛️ Homelab Repository Restructure: GitOps Standard Migration

> **Date:** 2026-08-22  
> **Objective:** Transition from legacy numbered Obsidian vault folders (`02-`, `04-`, `05-`, `06-`) to an enterprise-grade GitOps repository architecture (`docs/`, `iac/`, `compose/`, `scripts/`) across both private (`homelab`) and sanitized public (`homelab-infrastructure`) repositories.  
> **Maintainer:** Homelab Admin / Homelab Admin  
> **Outcome:** 100% modular, categorized, IP-abstracted, and publication-ready architecture.

---

## 1. Problem Statement & Motivation

1. **Obsidian Folder Legacy:** Numbered prefixes (`02-Proxmox`, `04-Network`, `04-Synology`, `05-Services`, `06-Guides`) were optimized for desktop Obsidian sorting, but created unnecessary cognitive load and visual clutter on GitHub.
2. **Flat Guide Directory:** Over 70 operational runbooks and troubleshooting post-mortems resided in a single flat directory (`06-Guides/`), making thematic search difficult.
3. **Scattered Artifacts:** Automation scripts, Docker Compose files, and Terraform manifests were dispersed across multiple unrelated subfolders.
4. **Information Security:** Live device IP addresses and transient runtime telemetry needed abstraction to standardized 802.1Q VLAN segments for the public mirror.

---

## 2. Target GitOps Architecture

Both repositories now adhere to the standardized GitOps directory structure:

```
├── docs/                                 # 📖 All Markdown Architectural & Operational Docs
│   ├── architecture/                     # High-level cluster design & network topology
│   │   ├── cluster-topology.md           # PVE multi-node hypervisor cluster design
│   │   ├── network-vlan-schema.md        # 802.1Q VLAN matrix & DNS split-horizon
│   │   ├── storage-architecture.md       # Synology NAS & ZFS storage tiering
│   │   ├── unifi-gateway-setup.md        # UCG Max gateway routing & firewall rules
│   │   └── unraid-legacy-postmortem.md   # Hardware crash & migration analysis
│   ├── guides/                           # Categorized Step-by-Step Runbooks
│   │   ├── media-automation/             # Arr stack, Plex GPU transcode, Jellyfin HA
│   │   ├── security-ingress/             # Authentik SSO, Cloudflare tunnels, NPM SSL, Wazuh SIEM
│   │   ├── hypervisor-cluster/           # PVE cluster join, UEFI PXE boot, VM optimization
│   │   └── disaster-recovery/            # DR audits, mount recoveries, storage deadlocks
│   └── services/                         # Service catalog & individual application deep-dives
│       ├── services-index.md
│       ├── authentik.md
│       ├── nginx-proxy-manager.md
│       └── cloudflared.md
│
├── iac/                                  # 🏗️ Declarative Infrastructure-as-Code
│   ├── terraform/                        # Terraform modules & environment definitions
│   │   ├── proxmox/
│   │   ├── unifi/
│   │   └── unraid/
│   └── ansible/                          # Rolling Proxmox update automation playbooks
│
├── compose/                              # 🐳 Version-controlled Docker Compose templates
│   ├── arr-stack/                        # Acquisition stack with WireGuard killswitch
│   ├── dashboard/                        # Homepage & Heimdall configs
│   └── immich/                           # Machine learning photo vault stack
│
└── scripts/                              # ⚡ Operational Automation Scripts
    ├── backup-replication/               # Rsync & Synology backup sync scripts
    ├── maintenance/                      # Automated update rollback & health check scripts
    └── media-tools/                      # Metadata standardization & clean-up tools
```

---

## 3. Migration Pipeline

A migration script was developed to safely perform the following operations:

1. **Categorize 70+ Operational Guides:** Evaluated keyword matching to separate media workflows, security controls, hypervisor tuning, and disaster recovery post-mortems into dedicated subfolders.
2. **Consolidate Docker Stacks:** Relocated Homepage, Immich, and Arr Stack compose files into `compose/`.
3. **Organize Automation Scripts:** Grouped 40+ PowerShell and Bash scripts into `scripts/backup-replication`, `scripts/maintenance`, and `scripts/media-tools`.
4. **Synchronize Root Showcases:** Updated `README.md` in both repositories with the new directory tree, topology diagrams, and master service catalogs.
5. **Enforce Public Redaction:** Abstracted all device IPs to 802.1Q VLAN identifiers in `homelab-infrastructure` and purged old commit references.

---

## 4. Outcome & Verification

- **Private Vault (`homelab`):** Successfully reorganized into clean GitOps layout with Git history preserved.
- **Public Mirror (`homelab-infrastructure`):** Fully sanitized, IP-abstracted, reorganized, and pushed to remote `main` branch.
- **Zero Broken Links:** All relative links inside `README.md` have been updated and verified.
