# 🛡️ Disaster Recovery: Infrastructure Audit

This document provides a point-in-time snapshot of all LXC containers running on the Homelab-Net homelab. Use this as a reference for re-mounting storage, re-assigning IP addresses, and verifying resource allocations during a recovery event.

**Audit Date**: 2026-05-15  
**Nodes**: Bulakan (`192.168.1.25`), Cebu (`192.168.1.26`)

---

## 🏗️ Node: Bulakan (192.168.1.25)

| VMID | Name | Status | IP Address | RAM / Cores | Storage (Root / Mounts) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **100** | audiobookshelf | Running | 192.168.1.59 | 2GB / 2 | Root: 4G (Bulakan-ZFS) <br> Mount: `/mnt/audiobooks` |
| **102** | nginxproxymanager| Stopped | 192.168.1.101 | 1GB / 2 | Root: 8G (Bulakan-ZFS) |
| **104** | plex | Running | 192.168.1.54 | 4GB / 2 | Root: 32G (Bulakan-ZFS) <br> Mounts: `/mnt/plex`, `/mnt/plex1` |
| **106** | sonarr | Stopped | 192.168.1.135 | 4GB / 2 | Root: 8G (Bulakan-ZFS) |
| **107** | bazarr | Stopped | 192.168.1.137 | 1GB / 2 | Root: 8G (Bulakan-ZFS) |
| **108** | jackett | Running | 192.168.1.58 | 512MB / 1 | Root: 8G (Bulakan-ZFS) |
| **110** | jellyfin | Running | 192.168.1.126 | 4GB / 2 | Root: 30G (Bulakan-ZFS) <br> Mounts: `/mnt/plex`, `/mnt/plex1` |
| **115** | heimdall-dashboard| Stopped | DHCP | 512MB / 1 | Root: 4G (Bulakan-ZFS) |
| **118** | netbootxyz | Stopped | DHCP | 1GB / 2 | Root: 16G (Bulakan-ZFS) |
| **301** | pihole | Running | 192.168.1.4 | 512MB / 2 | Root: 4G (Bulakan-ZFS) |
| **304** | cloudflared | Running | 192.168.1.6 | 1GB / 2 | Root: 8G (Bulakan-ZFS) |

---

## 🏗️ Node: Cebu (192.168.1.26)

| VMID | Name | Status | IP Address | RAM / Cores | Storage (Root / Mounts) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **103** | authentik | Running | 192.168.1.225 | 4GB / 4 | Root: 16G (cebu-zfs) <br> Mount: `/opt/authentik-data` (1G) |
| **105** | nginxproxymanager| Stopped | 192.168.1.210 | 2GB / 2 | Root: 8G (cebu-zfs) |
| **401** | pihole-cebu | Running | 192.168.1.134 | 512MB / 2 | Root: 8G (cebu-zfs) <br> Bridge: `vnet1` |
| **404** | cloudflared-cebu | Running | 192.168.1.7 | 512MB / 2 | Root: 4G (cebu-zfs) |
| **416** | jellyfin-cebu | Stopped | 192.168.1.41 | 4GB / 4 | Root: 32G (cebu-zfs) <br> Mount: `/mnt/seagate` |

---

## ⚠️ Critical Dependencies

### 1. Storage Mounts (PNAS)
Most media containers rely on the Synology NAS (`PNAS` at `192.168.1.12`).
- If these containers show "Empty" libraries, verify the SMB/NFS mount at the Proxmox host level first.
- Mount point mappings are defined in `/etc/pve/lxc/<VMID>.conf`.

### 2. Networking
- **Bridge**: Most containers use `vmbr0` (Physical LAN).
- **Pi-hole Cebu (401)**: Uses `vnet1` (Isolated SDN VXLAN Bridge). If this bridge is missing, the container will fail to start.

### 3. GPU Passthrough
- **Jellyfin (110)**: Has Intel Quicksync passthrough configured. Requires specific GID mappings in the LXC config to function.

---

## 🔄 Recovery Workflow
1.  **Node Restore**: Ensure ZFS pools (`Bulakan-ZFS` or `cebu-zfs`) are healthy.
2.  **Config Sync**: Restore LXC `.conf` files from `/etc/pve/lxc/`.
3.  **Storage Attach**: Re-mount `PNAS` shared storage.
4.  **Network Start**: Ensure `vmbr0` and `vnet1` are active before starting containers.
