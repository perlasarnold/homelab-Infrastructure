# 📺 Dapitan Plex Media Server Setup & Access Recovery Guide

## Date

2026-07-24

## Objective

Troubleshoot, restore, and document the inaccessible **Plex Media Server** container (`plex-dapitan`, LXC Container `509`) on the **Dapitan** Proxmox VE host (`VLAN 1 [Management]`), ensuring static IP access at `VLAN 1 (Management):32400` and direct access to attached 18TB ZFS media storage (`/mnt/bindmounts/media-data/library`).

---

## Infrastructure Configuration

| Parameter | Value | Details |
|---|---|---|
| **Host Node** | `Dapitan` (`VLAN 1 [Management]`) | Node 3 in `Homelab-Net` cluster |
| **Container ID** | `509` | Proxmox LXC container |
| **Hostname** | `plex-dapitan` | Local container hostname |
| **Static IP Address** | `VLAN 1 (Management)` | Configured on `vmbr0` bridge |
| **Service Listening Port** | `32400` (TCP) | Default Plex Media Server HTTP port |
| **Web Access URL** | **[http://VLAN 1 (Management):32400/web](http://VLAN 1 (Management):32400/web)** | Web interface setup & management URL |
| **Media Mount Path** | `/media/library` | LXC bind-mount from host `/mnt/bindmounts/media-data/library` |

---

## Investigation & Root Cause

1. **Inaccessible IP Diagnosis**:
   - Navigation to `http://VLAN 1 (Management):32400/web` timed out or returned connection refused.
   - Proxmox container audit showed CT 509 (`plex-dapitan`) was active on host `Dapitan`, but service checks returned `Unit plexmediaserver.service could not be found`.
2. **Root Cause**:
   - Container `509` was initialised with temporary dynamic DHCP networking and an interrupted setup script in `/tmp/setup-plex.sh`.
   - The `plexmediaserver` package had not been installed, so no web daemon or socket was listening on TCP port `32400`.

---

## Steps Taken

### 1. Network Configuration Standardisation
Configured static IP allocation for CT 509 on host `Dapitan` to ensure IP stability:
```bash
pct set 509 -net0 name=eth0,bridge=vmbr0,hwaddr=00:11:22:33:44:55,ip=VLAN 1 (Management)/24,gw=VLAN 1 [Gateway]
pct reboot 509
```

### 2. Plex Media Server Installation
Inside CT 509, added the official Plex GPG signing key, configured the official repository, and installed `plexmediaserver`:
```bash
# Add official repository and GPG key
apt-get update
apt-get install -y curl ca-certificates rsync gpg wget
curl -fsSL https://downloads.plex.tv/plex-keys/PlexSign.key | gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/plex.gpg
echo "deb https://downloads.plex.tv/repo/deb/ public main" > /etc/apt/sources.list.d/plex.list

# Install Plex package
apt-get update
apt-get install -y plexmediaserver
```

### 3. ZFS Media Dataset Permissions
Verified bind mount configuration in `/etc/pve/lxc/509.conf`:
```text
mp0: /mnt/bindmounts/media-data/library,mp=/media/library
```
Set recursive ownership of `/media/library` to system user `plex:plex` inside CT 509:
```bash
pct exec 509 -- chown -R plex:plex /media/library
```
Verified readability of `/media/library/movies` and `/media/library/tv` datasets.

### 4. Service Verification & Network Connectivity Tests
- **Service Status**: `plexmediaserver.service` is `active (running)`.
- **Port Listening**: TCP port `32400` listening on `0.0.0.0:32400`.
- **Local HTTP Response**: `curl -Is http://127.0.0.1:32400/web` returned `HTTP/1.1 302 Moved Temporarily`.
- **LAN Access Response**: `curl.exe -Is http://VLAN 1 (Management):32400/web` returned `HTTP/1.1 302 Moved Temporarily`.

---

## Outcome

Dapitan Plex Media Server (CT 509) is fully online, listening on port `32400`, and accessible across the network at **[http://VLAN 1 (Management):32400/web](http://VLAN 1 (Management):32400/web)**. Media libraries `/media/library/movies` and `/media/library/tv` on the 18TB ZFS dataset are attached and ready for indexing.

---

## References

- [Plex Cloning Guide](./Plex%20Cloning%20Guide.md)
- [Dapitan Homelab-Net Cluster Join](./Dapitan-Homelab-Net-Cluster-Join-2026-07-23.md)
- [OptiPlex Proxmox Direct-Attached Storage Plan](./OptiPlex-Proxmox-Direct-Attached-Storage-Plan-2026-07-22.md)
