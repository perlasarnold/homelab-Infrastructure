# 🏠 Core Homelab

> **Status:** 🟢 Active | Last Updated: 2026-05-14

Welcome to the Core Homelab documentation vault. This notebook covers every component of the home server infrastructure in plain language — built so anyone (including a newcomer) can understand the layout and manage the environment.

---

## 🗺️ Quick Navigation

| Area | Description | Link |
|------|-------------|------|
| 🌐 Network Overview | IP map, VLANs, subnets | [[04-Network/Network Overview]] |
| 🖥️ Proxmox | Hypervisor, VMs & LXC containers | [[02-Proxmox/Proxmox Overview]] |
| 📦 Unraid | NAS, storage, Docker apps | [[03-Unraid/Unraid Overview]] |
| 🔧 Services | Running apps & services index | [[05-Services/Services Index]] |
| 📖 Guides | How-to guides for common tasks | [[06-Guides/Guides Index]] |

---

## 🏗️ Infrastructure at a Glance

```
Home Router / Gateway (192.168.1.1)
       │
       ├── 192.168.1.25  →  Proxmox Bulakan (Primary Node)
       │                       └── Core LXC Containers & VMs
       │
       ├── 192.168.1.26  →  Proxmox Cebu (Secondary Node)
       │                       └── Authentik, NPM (Active), Wazuh SIEM
       │
       ├── 192.168.1.27  →  Proxmox Dapitan (Storage & Media Node)
       │                       ├── 18TB ZFS Bulk Storage (/mnt/bindmounts)
       │                       └── Immich, Plex DP, Jellyfin DP
       │
       └── 192.168.1.12  →  PNAS Synology (Shared PVE Storage)
```

---

## 📋 Server Quick Reference

| Server | IP | Role | Web UI |
|--------|----|------|--------|
| Proxmox Bulakan | `192.168.1.25` | Primary Hypervisor | https://192.168.1.25:8006 |
| Proxmox Cebu | `192.168.1.26` | Secondary Hypervisor | https://192.168.1.26:8006 |
| Proxmox Dapitan | `192.168.1.27` | Bulk Storage Hypervisor | https://192.168.1.27:8006 |
| PNAS Synology | `192.168.1.12` | Network Attached Storage | https://192.168.1.12:5001 |

---

## 📂 Vault Structure

```
homelab-setup/
├── 01-Overview/          →  High-level architecture docs
├── 02-Proxmox/           →  Proxmox host, VMs, containers
├── 03-Unraid/            →  Unraid shares, plugins, Docker
├── 04-Network/           →  IP layout, DNS, firewall rules
├── 05-Services/          →  Per-service documentation
├── 06-Guides/            →  Step-by-step how-to guides
└── Assets/               →  Diagrams, screenshots
```

---

*📝 This vault is maintained in `U:\HomeLab\homelab-setup` and versioned with Git.*
