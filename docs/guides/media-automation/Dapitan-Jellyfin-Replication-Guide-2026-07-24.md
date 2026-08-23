# 🎬 Dapitan Jellyfin Media Server Replication Guide

## Date

2026-07-24

## Objective

Provision and replicate the **Jellyfin Media Server** container (`jellyfin-dapitan`, LXC Container `510`) on the **Dapitan** Proxmox VE host (`VLAN 1 [Management]`) from the existing Cebu Jellyfin server (CT `416`), attaching the local 18TB ZFS media dataset path `/mnt/bindmounts/media-data/library` (`\\VLAN 1 [Management]\media-data\library`).

---

## Infrastructure Configuration

| Parameter | Value | Details |
|---|---|---|
| **Host Node** | `Dapitan` (`VLAN 1 [Management]`) | Node 3 in `Homelab-Net` cluster |
| **Container ID** | `510` | Proxmox LXC container |
| **Hostname** | `jellyfin-dapitan` | Container hostname |
| **OS Template** | Debian 12 (bookworm) | Standard minimal Debian LXC template |
| **IP Address** | `VLAN 1 (Management)` | Configured on `vmbr0` bridge |
| **Service Listening Port** | `8096` (TCP) | Default Jellyfin HTTP port |
| **Web Access URL** | **[http://VLAN 1 (Management):8096](http://VLAN 1 (Management):8096)** | Web interface URL |
| **Media Mount Path** | `/media/library` | LXC bind-mount from host `/mnt/bindmounts/media-data/library` |

---

## Troubleshooting & Network Resolution

- **Issue**: Initial static IP `VLAN 1 [Management]` caused TCP connection resets (`ERR_CONNECTION_REFUSED`) from local network clients due to router ARP table routing behavior for static IPs outside the router's active DHCP range.
- **Resolution**: Updated container network interface `net0` to IP `VLAN 1 (Management)/24` (Gateway `VLAN 1 [Gateway]`), created `/usr/share/jellyfin/web` to `/var/lib/jellyfin/wwwroot` static asset symlink, and set explicit local network subnet permissions in `/etc/jellyfin/network.xml`.
- **Result**: External LAN requests return `HTTP 200 OK` instantly on `http://VLAN 1 (Management):8096`.

---

## Steps Taken

### 1. Provisioned LXC Container 510 on Dapitan
Created container `510` (`jellyfin-dapitan`) on storage `vm-fast` with 4 CPU cores, 4096MB RAM, 512MB Swap, and 32GB NVMe root filesystem:
```bash
pct create 510 PNAS:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst \
  --hostname jellyfin-dapitan \
  --cores 4 \
  --memory 4096 \
  --swap 512 \
  --storage vm-fast \
  --rootfs vm-fast:32 \
  --features keyctl=1,nesting=1 \
  --net0 name=eth0,bridge=vmbr0,ip=VLAN 1 (Management)/24,gw=VLAN 1 [Gateway] \
  --mp0 /mnt/bindmounts/media-data/library,mp=/media/library \
  --onboot 1 \
  --unprivileged 1
pct start 510
```

### 2. Installed Official Jellyfin Media Server Package
Configured official Jellyfin APT repository inside CT 510:
```bash
apt-get update
apt-get install -y curl ca-certificates gnupg rsync
mkdir -p /etc/apt/keyrings
curl -fsSL https://repo.jellyfin.org/jellyfin_team.gpg.key | gpg --dearmor --yes -o /etc/apt/keyrings/jellyfin.gpg

cat << 'SOURCES' > /etc/apt/sources.list.d/jellyfin.sources
Types: deb
URIs: https://repo.jellyfin.org/debian
Suites: bookworm
Components: main
Architectures: amd64
Signed-By: /etc/apt/keyrings/jellyfin.gpg
SOURCES

apt-get update
apt-get install -y jellyfin
```

### 3. Replicated Configuration & Database from Cebu (CT 416)
Synchronized user accounts, watched status, plugins, and metadata databases directly from `jellyfin-cebu` (CT 416) to `jellyfin-dapitan` (CT 510):
```bash
# Stop Jellyfin on both containers
ssh root@VLAN 1 [Management] "pct exec 510 -- systemctl stop jellyfin"
ssh root@VLAN 1 [Management] "pct exec 416 -- systemctl stop jellyfin"

# Transfer data structures
ssh root@VLAN 1 [Management] "pct exec 416 -- tar -cf - /var/lib/jellyfin /etc/jellyfin" | \
  ssh root@VLAN 1 [Management] "pct exec 510 -- tar -xf - -C /"

# Restart Cebu Jellyfin
ssh root@VLAN 1 [Management] "pct exec 416 -- systemctl start jellyfin"
```

### 4. Network Configuration & Web Root Symlink
Updated `/etc/jellyfin/network.xml` and created static asset web symlink:
```bash
pct exec 510 -- ln -snf /usr/share/jellyfin/web /var/lib/jellyfin/wwwroot
pct exec 510 -- chown -R jellyfin:jellyfin /var/lib/jellyfin /etc/jellyfin
pct exec 510 -- systemctl restart jellyfin
```

---

## Verification & Status Audit

- **Service Status**: `jellyfin.service` is `active (running)`.
- **Port Listening**: TCP port `8096` listening on `0.0.0.0:8096`.
- **Local HTTP Test**: `curl -Is http://127.0.0.1:8096` returned `HTTP/1.1 302 Found`.
- **LAN Web Interface Test**: `(Invoke-WebRequest -Uri 'http://VLAN 1 (Management):8096/web/index.html').StatusCode` returned `200`.
- **Media Library Mount**: `/media/library` (`movies` and `tv` datasets) confirmed readable by system user `jellyfin`.

---

## Outcome

Dapitan Jellyfin Media Server (CT `510`) is online and accessible at **[http://VLAN 1 (Management):8096](http://VLAN 1 (Management):8096)** with all user accounts and configuration cloned from Cebu, attached directly to host dataset `\\VLAN 1 [Management]\media-data\library` (`/media/library`).

---

## References

- [Cebu Jellyfin Setup Guide](./Cebu-Jellyfin-Setup-Guide.md)
- [Dapitan Plex Setup & Access Recovery Guide](./Dapitan-Plex-Setup-Recovery-2026-07-24.md)
- [Dapitan Homelab-Net Cluster Join](./Dapitan-Homelab-Net-Cluster-Join-2026-07-23.md)
