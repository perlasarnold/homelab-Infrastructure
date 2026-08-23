# 🌐 Netboot.xyz

> Self-hosted PXE/iPXE boot server for network-based OS installations and recovery tools.  
> **Container ID:** 118 | **IP:** 192.168.1.54 | **Web UI:** http://192.168.1.54:3000

---

## What is netboot.xyz?

[netboot.xyz](https://netboot.xyz) is a collection of iPXE scripts that enables network booting of:

| Category | Examples |
|----------|----------|
| **Linux Distros** | Ubuntu, Debian, Fedora, Arch, Alpine, etc. |
| **Rescue Tools** | SystemRescue, Clonezilla, GParted, etc. |
| **Network Installers** | Windows PE, various ISOs |
| **Utilities** | Memtest86+, DBAN, etc. |

Instead of creating USB drives or mounting ISOs, netboot.xyz downloads and boots everything over HTTP from your local network.

---

## Quick Reference

| Detail | Value |
|--------|-------|
| **Container Type** | LXC (Proxmox) |
| **Template** | Debian 12 (unmanaged) via tteck helper script |
| **VM ID** | 118 |
| **Hostname** | netbootxyz |
| **Static IP** | 192.168.1.54/24 |
| **Gateway** | 192.168.1.1 |
| **CPU/Memory** | 2 cores / 1 GiB |
| **Disk** | 16 GiB (ZFS - Bulakan-ZFS) |
| **Nesting** | Enabled |

### Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 69 | UDP | TFTP (PXE boot files) |
| 80 | TCP | HTTP (boot assets, primary) |
| 3000 | TCP | Web management UI |
| 8080 | TCP | HTTP (alternative) |

---

## Deployment

### 1. Terraform Apply

The container is defined in `terraform/proxmox/lxc.tf`. Deploy it:

```powershell
cd terraform/proxmox
terraform init
terraform plan
terraform apply
```

### 2. Install netboot.xyz Software

The container uses `type = "unmanaged"` so you need to manually install the software after creation:

```bash
# Access the container from Proxmox shell
pct exec 118 -- bash

# Download and run the tteck helper script
bash -c "$(wget -qLO - https://github.com/tteck/Proxmox/raw/main/ct/netbootxyz.sh)"
```

The script will:
- Install Docker and Docker Compose
- Clone the netboot.xyz-docker repository
- Set up the web UI on port 3000
- Configure TFTP and HTTP services

### 3. Verify Installation

After the script completes:

```bash
# Check services are running
docker ps

# Expected output:
# netbootxyz-web      # Web UI on :3000
# netbootxyz-tftp     # TFTP on :69
# netbootxyz-nginx    # HTTP on :80/:8080
```

Access the web UI: http://192.168.1.54:3000

---

## Initial Configuration

### Web UI Setup

1. Navigate to `http://192.168.1.54:3000`
2. First login: No authentication by default (configure if desired)
3. Review settings:
   - **Local Assets:** Enable to cache ISOs locally (saves bandwidth)
   - **Asset Storage:** Configure path (e.g., `/assets` in container)
   - **Menus:** Customize which OS options appear

### Enable Local Asset Caching (Recommended)

Local caching stores downloaded ISOs on the container, speeding up subsequent boots:

1. Web UI → **Settings** → **Local Assets**
2. Enable: ✅ **Cache Assets Locally**
3. Set storage path: `/assets` (maps to container disk)
4. Click **Save**

First boot of any OS will download to cache; subsequent boots serve from local storage.

---

## DHCP/PXE Configuration

To make clients network boot from netboot.xyz, configure your DHCP server (usually your router or Pi-hole).

### Option 1: Pi-hole DHCP (Recommended)

If using Pi-hole (CT 301 or Unraid) as DHCP server:

1. **Pi-hole Admin** → **Settings** → **DHCP**
2. Enable DHCP if not already enabled
3. Configure **PXE/OpenBoot** options:

| Setting | Value |
|---------|-------|
| **Boot Server** | `192.168.1.54` |
| **Boot Filename** | `netboot.xyz.kpxe` (BIOS) or `netboot.xyz.efi` (UEFI) |

4. Save settings

### Option 2: OPNsense/pfSense

**Services** → **DHCP Server** → **LAN**:

| Setting | Value |
|---------|-------|
| **TFTP Server** | `192.168.1.54` |
| **Network Booting** → **Enable** | ✅ Checked |
| **Next Server** | `192.168.1.54` |
| **Default BIOS file name** | `netboot.xyz.kpxe` |
| **UEFI 32 bit file name** | `netboot.xyz.efi` |
| **UEFI 64 bit file name** | `netboot.xyz.efi` |

### Option 3: Router/Other DHCP

Consult your router documentation. Look for:
- **TFTP Server IP:** `192.168.1.54`
- **Boot Filename:** `netboot.xyz.kpxe` (BIOS) or `netboot.xyz.efi` (UEFI)
- **DHCP Options:** 66 (TFTP server name) and 67 (bootfile name)

### Option 4: Chainloading from Existing PXE

If you already have a PXE server, add a menu entry:

```bash
# iPXE chainload netboot.xyz
kernel http://192.168.1.54/netboot.xyz.lkrn
boot
```

---

## Client Boot Instructions

### UEFI Systems

1. Enter BIOS/UEFI settings (F2, F10, F12, DEL depending on vendor)
2. Enable **Network Stack** / **PXE Boot**
3. Set boot priority: **Network/PXE** first
4. Save and exit
5. System will download `netboot.xyz.efi` and boot to menu

### Legacy BIOS Systems

1. Enter BIOS setup
2. Enable **PXE Boot** or **Network Boot**
3. Set boot order: **Network first**
4. Save and exit

### UEFI Secure Boot

netboot.xyz is **not signed** for Secure Boot. Solutions:

1. **Disable Secure Boot** in BIOS temporarily
2. **Enroll custom key** (advanced, per-organization)
3. Use USB method for Secure Boot systems

### USB Fallback Method

For systems without PXE or Secure Boot issues:

```bash
# Download IPXE bootable USB image
wget https://boot.netboot.xyz/ipxe/netboot.xyz.iso

# Flash to USB (Linux/macOS)
dd if=netboot.xyz.iso of=/dev/sdX bs=4M status=progress

# Flash to USB (Windows) - use Rufus
```

---

## Docker Compose Configuration

If you need to modify the deployment, edit `/opt/netbootxyz/docker-compose.yml`:

```yaml
version: "3.8"
services:
  web:
    image: ghcr.io/netbootxyz/webapp:latest
    ports:
      - "3000:3000"      # Web UI
    environment:
      - MENU_VERSION=2.x
      - PORT_RANGE=30000-30100
    volumes:
      - ./config:/config   # Config persistence
      - ./assets:/assets   # ISO cache
    restart: unless-stopped

  tftp:
    image: ghcr.io/netbootxyz/tftp:latest
    ports:
      - "69:69/udp"      # TFTP
    volumes:
      - ./config:/config
    restart: unless-stopped

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"          # HTTP boot
      - "8080:8080"      # Alt HTTP
    volumes:
      - ./config/nginx.conf:/etc/nginx/nginx.conf
      - ./assets:/assets
    restart: unless-stopped
```

Restart after changes:
```bash
cd /opt/netbootxyz
docker-compose down
docker-compose up -d
```

---

## Maintenance

### Update netboot.xyz

```bash
pct exec 118 -- bash
cd /opt/netbootxyz
docker-compose pull
docker-compose up -d
```

### Clear Asset Cache

If disk fills up or you want fresh downloads:

```bash
pct exec 118 -- bash
rm -rf /opt/netbootxyz/assets/*
# Or via Web UI: Settings → Local Assets → Clear Cache
```

### Backup Configuration

```bash
# From Proxmox host
pct mount 118
cp -r /var/lib/lxc/118/rootfs/opt/netbootxyz/config /path/to/backup/
pct unmount 118
```

### Container Updates (via Terraform)

```powershell
cd terraform/proxmox
terraform taint proxmox_virtual_environment_container.netbootxyz
terraform apply
# Then re-install netboot.xyz software
```

---

## Troubleshooting

### Client Can't Find PXE Server

| Check | Command |
|-------|---------|
| Container running? | `pct status 118` |
| Services running? | `pct exec 118 -- docker ps` |
| Network connectivity? | `ping 192.168.1.54` from client |
| DHCP options set? | Check router/Pi-hole DHCP settings |
| Firewall blocking? | Check UFW/iptables in container |

### Slow Boot Speeds

- Enable **Local Asset Caching** in Web UI
- Ensure container has sufficient disk (16GB recommended for caching)
- Check network speed between client and server

### "File not found" Errors

- Verify TFTP server is running: `pct exec 118 -- netstat -ulnp | grep 69`
- Check boot filename in DHCP: should be `netboot.xyz.kpxe` or `netboot.xyz.efi`

### Container Won't Start

```bash
# Check Proxmox logs
pct logs 118

# Check LXC config
cat /etc/pve/lxc/118.conf

# Ensure nesting is enabled (required for Docker)
grep features /etc/pve/lxc/118.conf
# Should show: features: nesting=1
```

---

## Security Considerations

| Concern | Recommendation |
|---------|------------------|
| **Unauthenticated UI** | Place behind reverse proxy (NPM/Traefik) with auth if externally exposed |
| **TFTP exposure** | TFTP is unencrypted; use only on trusted LAN |
| **Asset integrity** | Cached ISOs should be verified if security-critical |
| **Network isolation** | Consider VLAN for PXE if in untrusted environments |

---

## Resources

- **Project:** https://netboot.xyz
- **Docker Docs:** https://github.com/netbootxyz/netboot.xyz-docker
- **tteck Script:** https://tteck.github.io/Proxmox/
- **IPXE Docs:** https://ipxe.org

---

## Related

- [[Proxmox Overview]] — Main Proxmox documentation
- [[Services Index]] — All homelab services
- [[04-Network/Network Overview]] — DHCP and network configuration

---

**Tags:** #proxmox #lxc #pxe #networking #boot #infrastructure #proxmox-helper-scripts
