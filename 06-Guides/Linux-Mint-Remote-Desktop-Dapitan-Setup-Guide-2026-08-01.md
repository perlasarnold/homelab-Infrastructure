# 🐧 Linux Mint Remote Desktop Jump Box Setup Guide (Dapitan Node)

- **Date:** August 1, 2026
- **Objective:** Design, allocate, and document the deployment of a high-performance **Linux Mint 22 Desktop VM** on Proxmox node **Dapitan** (128GB disk on `vm-fast` pool), configured with **VLAN 20 (TRUSTED)** network placement, **Apache Guacamole** HTML5 streaming, and **Authentik MFA** for zero-trust remote browser access (self-hosted Google Remote Desktop replacement).
- **Target Host:** Proxmox VE Node 3 `Dapitan` (`192.168.1.27` / `192.168.10.27`)
- **Status:** Architecture Approved / Ready for Deployment

---

## 🌐 Network VLAN Assignment & Security Strategy

### Recommended VLAN: **VLAN 20 — TRUSTED (`192.168.20.0/24`)**
- **Recommended Static IP:** `192.168.20.70` *(or `192.168.1.70` during flat-network transition)*
- **Gateway:** `192.168.20.1` (UniFi Cloud Gateway Max)

### Architectural Rationale:

```
┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                     NETWORK VLAN MATRIX EVALUATION                               │
├─────────────────┬───────────────────┬────────────────────────────────────────────────────────────┤
│ Network Subnet  │ VLAN Tag / ID     │ Architectural Suitability & Verdict                       │
├─────────────────┼───────────────────┼────────────────────────────────────────────────────────────┤
│ TRUSTED         │ VLAN 20           │ ✅ **BEST CHOICE (RECOMMENDED)**                           │
│                 │                   │ Functions as your remote **Admin Workstation / Jump Box**. │
│                 │                   │ Stateful firewall rules allow outbound admin access into   │
│                 │                   │ MGMT (VLAN 10), SERVICES (VLAN 110), and IOT (VLAN 30).    │
├─────────────────┼───────────────────┼────────────────────────────────────────────────────────────┤
│ SERVICES        │ VLAN 110          │ ⚠️ Secondary Option                                        │
│                 │                   │ Treats the desktop as an app host (like Plex/Immich).     │
│                 │                   │ Limits administrative management reach unless firewall     │
│                 │                   │ exceptions are explicitly carved out.                     │
├─────────────────┼───────────────────┼────────────────────────────────────────────────────────────┤
│ MGMT            │ VLAN 10           │ ❌ Not Recommended for Desktop OS                          │
│                 │                   │ Reserved strictly for hypervisors, switches, & PNAS DSM.   │
├─────────────────┼───────────────────┼────────────────────────────────────────────────────────────┤
│ DMZ             │ VLAN 120          │ ⛔ HIGH RISK — PROHIBITED                                  │
│                 │                   │ Directly exposed via public proxies/tunnels.              │
└─────────────────┴───────────────────┴────────────────────────────────────────────────────────────┘
```

#### Why VLAN 20 (TRUSTED)?
1. **Administrative Jump Host Capability:** Once connected to the Linux Mint desktop via Guacamole, you need the capability to manage Proxmox VE nodes (`192.168.10.x`), Synology/TrueNAS interfaces (`192.168.10.12`), and service containers (`192.168.110.x`). VLAN 20 is designated for trusted admin endpoints.
2. **Stateful Ingress Isolation:** UniFi stateful firewall rules prevent low-trust networks (DMZ VLAN 120, IOT VLAN 30) from initiating connections to VLAN 20, while permitting Apache Guacamole (SERVICES VLAN 110) to reach the desktop strictly on the RDP port (`3389`).

---

## 🏗️ Remote Ingress & Authentication Architecture

This architecture replaces third-party tools like Google Remote Desktop with a **100% self-hosted, Zero-Trust browser-native remote desktop solution**:

```
 🌐 [ Public Internet Client ]
                │
                │ HTTPS (TLS 443)
                ▼
 🛡️ [ Cloudflare Tunnel / Public Ingress ] ◄── DMZ (VLAN 120)
                │
                ▼
 🔐 [ Authentik IdP Gateway ] (192.168.110.225) ◄── SERVICES (VLAN 110)
        ├── Multi-Factor Auth (WebAuthn / YubiKey / TOTP)
        └── OIDC / Proxy Authorization
                │
                ▼ (Authenticated Session)
 💻 [ Apache Guacamole Server ] (192.168.110.x) ◄── SERVICES (VLAN 110)
        ├── HTML5 Canvas & WebSocket Web Engine
        └── guacd (RDP / VNC Translation Engine)
                │
                │ RDP (Port 3389)
                ▼
 🖥️ [ Linux Mint 22 Desktop VM ] (192.168.20.70) ◄── TRUSTED (VLAN 20)
        ├── 128GB ZFS Disk (`vm-fast` pool on Dapitan)
        ├── xrdp + xorgxrdp + Audio Redirection
        └── Full Remote Desktop Jump Box
```

### Core Benefits vs. Google Remote Desktop (CRD):
* **Hardware MFA Support:** Enforces YubiKey / FIDO2 WebAuthn & TOTP via Authentik before exposing any desktop interface.
* **No Third-Party Cloud Relays:** All desktop audio, video, and input streams stay within your self-hosted infrastructure.
* **Browser Native:** Works in any modern Web Browser (Chrome, Safari, Firefox, iOS/Android tablets) without installing Chrome Remote Desktop host daemons or browser extensions.
* **Audit & Session Control:** Full administrative logging in Authentik and Guacamole.

---

## 🖥️ Proxmox VM Configuration (Dapitan Node)

### Hardware Specification & Storage Allocation:

| Parameter | Recommended Value | Notes |
| :--- | :--- | :--- |
| **Target Proxmox Node** | `Dapitan` (`192.168.1.27` / `192.168.10.27`) | Node 3 in Homelab-Net cluster |
| **VM ID** | `505` | Follows Dapitan guest naming standard (`5xx`) |
| **VM Name** | `mint-desktop-dapitan` | Descriptive hostname |
| **OS ISO** | `linuxmint-22-cinnamon-64bit.iso` | Cinnamon or XFCE edition |
| **Storage Pool** | `vm-fast` | Samsung 870 QVO ZFS Pool on Dapitan |
| **Disk Size** | **128 GB (`128G`)** | Allocated space as requested |
| **Disk Controller** | `VirtIO SCSI single` | Enabled with Discard (TRIM) & iothread |
| **CPU Cores** | `4 Cores` | CPU Type: `host` |
| **Memory (RAM)** | `8192 MB` (8 GB) | Ballooning enabled (min: 4GB, max: 8GB) |
| **Network Interface** | `vmbr0` | VLAN Tag: `20` (TRUSTED), Model: `VirtIO` |
| **Display** | `virtio-gl` or `std` | Standard VGA / SPICE driver |

---

## 🛠️ Step-by-Step Implementation Workflow

### Step 1: Provision the VM via Terraform (Infrastructure as Code)

The VM specification is declared in `/opt/homelab-infrastructure\terraform\proxmox\dapitan_mint_desktop.tf`.

1. Navigate to the Proxmox Terraform directory:
   ```bash
   cd /opt/homelab-infrastructure/terraform/proxmox
   ```

2. Inspect the Terraform definition (`dapitan_mint_desktop.tf`):
   ```hcl
   resource "proxmox_virtual_environment_vm" "mint_desktop_dapitan" {
     node_name   = "Dapitan"
     vm_id       = 505
     name        = "mint-desktop-dapitan"
     description = "Linux Mint 22 Remote Desktop Jump Box on Dapitan Node (128GB disk on vm-fast, VLAN 20 TRUSTED)"
     tags        = ["linux", "mint", "desktop", "remote-access", "dapitan"]
     on_boot     = true
     started     = true

     agent {
       enabled = true
     }

     cpu {
       cores = 4
       type  = "host"
     }

     memory {
       dedicated = 8192
     }

     disk {
       datastore_id = "vm-fast"
       interface    = "scsi0"
       size         = 128
       iothread     = true
       discard      = "on"
     }

     cdrom {
       enabled   = true
       file_id   = "local:iso/linuxmint-22-cinnamon-64bit.iso"
       interface = "ide2"
     }

     network_device {
       bridge  = "vmbr0"
       model   = "virtio"
       vlan_id = 20
     }

     operating_system {
       type = "l26"
     }

     boot_order = ["scsi0", "ide2", "net0"]
   }
   ```

3. Run Terraform to plan and apply:
   ```bash
   terraform plan -target=proxmox_virtual_environment_vm.mint_desktop_dapitan
   terraform apply -target=proxmox_virtual_environment_vm.mint_desktop_dapitan
   ```

---

### Alternative: Provision via Proxmox CLI (`qm`)

Execute on Proxmox Node **Dapitan** via PVE Shell or Web GUI:

```bash
# 1. Download Linux Mint 22 ISO to Dapitan local storage (if not present)
cd /var/lib/vz/template/iso
wget https://mirrors.kernel.org/linuxmint/stable/22/linuxmint-22-cinnamon-64bit.iso

# 2. Provision VM 505 with 128GB disk on vm-fast ZFS pool
qm create 505 \
  --name mint-desktop-dapitan \
  --ostype l26 \
  --cores 4 \
  --cpu host \
  --memory 8192 \
  --balloon 4096 \
  --scsihw virtio-scsi-single \
  --scsi0 vm-fast:128,discard=on,iothread=1 \
  --net0 virtio,bridge=vmbr0,tag=20 \
  --cdrom local:iso/linuxmint-22-cinnamon-64bit.iso \
  --boot order=scsi0;cdrom;net0 \
  --onboot 1

# 3. Start VM to run Linux Mint GUI installer
qm start 505
```

---

### Step 2: Install & Configure Linux Mint Desktop

1. Open the Proxmox noVNC console for VM `505` and complete standard Linux Mint installation.
2. Set Hostname: `mint-desktop-dapitan`.
3. Set Static IP inside Mint or via UniFi DHCP Reservation:
   * **IPv4 Address:** `192.168.20.70`
   * **Subnet Mask:** `255.255.255.0` (`/24`)
   * **Gateway:** `192.168.20.1`
   * **DNS:** `192.168.110.5` (Pi-hole)

4. Install & Tune `xrdp` + `xorgxrdp` for Guacamole RDP Access:

```bash
# Update packages
sudo apt update && sudo apt upgrade -y

# Install XRDP and Xorg drivers
sudo apt install -y xrdp xorgxrdp pipewire-module-xrdp

# Add xrdp user to ssl-cert group
sudo adduser xrdp ssl-cert

# Enable and start XRDP service
sudo systemctl enable --now xrdp

# Configure Cinnamon session for XRDP (clearing DBUS environment conflicts)
echo "env -u SESSION_MANAGER -u DBUS_SESSION_BUS_ADDRESS cinnamon-session" > ~/.xsession
chmod +x ~/.xsession

# Prevent display sleep / lock screen interference on headless boot
gsettings set org.cinnamon.desktop.session idle-delay 0
gsettings set org.cinnamon.desktop.screensaver lock-enabled false

# NOTE: Make sure to log out of the local Proxmox noVNC console session, 
# as Linux Mint prevents dual concurrent graphical sessions for the same user.
```

---

### Step 3: Deploy Apache Guacamole Server (SERVICES VLAN 110)

Deploy Apache Guacamole on an internal container/VM in **VLAN 110 (SERVICES)** using Docker Compose:

`docker-compose.yml` for Guacamole:
```yaml
version: '3.8'

services:
  guacd:
    image: guacamole/guacd:latest
    container_name: guacamole-guacd
    restart: always

  guacamole-db:
    image: postgres:15-alpine
    container_name: guacamole-db
    environment:
      POSTGRES_DB: guacamole_db
      POSTGRES_USER: guacamole_user
      POSTGRES_PASSWORD: "SuperSecureDbPassword123!"
    volumes:
      - guacamole-db-data:/var/lib/postgresql/data
    restart: always

  guacamole:
    image: guacamole/guacamole:latest
    container_name: guacamole-web
    restart: always
    ports:
      - "8085:8080"
    environment:
      GUACD_HOSTNAME: guacd
      POSTGRESQL_HOSTNAME: guacamole-db
      POSTGRESQL_DATABASE: guacamole_db
      POSTGRESQL_USER: guacamole_user
      POSTGRESQL_PASSWORD: "SuperSecureDbPassword123!"
    depends_on:
      - guacd
      - guacamole-db

volumes:
  guacamole-db-data:
```

---

### Step 4: Integrate Authentik Multi-Factor Authentication (MFA)

1. **Log in to Authentik Admin Interface:** `https://auth.homelab-admin.me/if/admin/`
2. **Option A: OIDC Integration (Native Guacamole Extension):**
   * Create an OAuth2 Provider in Authentik named `Provider-Guacamole`.
   * Client Type: `Confidential`, Authorization Flow: `default-provider-authorization-explicit-consent`.
   * Set Redirect URI: `https://remote.homelab-admin.me/guacamole/api/tokens`.
   * Install `guacamole-auth-openid` extension into Guacamole docker container.

3. **Option B: Authentik Proxy / Forward Auth Provider (Recommended Simpler Setup):**
   * Create a Proxy Provider in Authentik named `Guacamole-Proxy`.
   * External Host: `https://remote.homelab-admin.me`
   * Forward Auth mode: Single Application / Proxy.
   * Attach **MFA Policy** (Require TOTP or WebAuthn hardware key).

4. **In Guacamole Web UI (`http://192.168.1.212:8080/guacamole/`):**
   * Add Connection: `Dapitan-Mint`
   * Protocol: `RDP`
   * Hostname: `192.168.20.192` (Linux Mint Desktop IP)
   * Port: `3389`
   * Username: `homelab-admin`
   * Security Mode: `Any` (Crucial: Avoid NLA errors with xrdp)
   * Ignore server certificate: `Checked` (Required for self-signed TLS certs)
   * Performance Flags: Enable Font Smoothing, Desktop Composition, Audio Redirection.

---

### Step 5: UniFi Gateway Stateful Firewall Rules

Configure the following firewall rules on UniFi Cloud Gateway Max (`192.168.1.1`):

1. **Rule 1 (Guacamole to Desktop RDP):**
   * **Action:** Accept
   * **Source:** SERVICES (VLAN 110) — IP of Guacamole Server
   * **Destination:** TRUSTED (VLAN 20) — `192.168.20.70` (Linux Mint Desktop)
   * **Port:** TCP `3389`

2. **Rule 2 (Linux Mint Outbound Admin Reach):**
   * **Action:** Accept (Stateful / Established Return)
   * **Source:** TRUSTED (VLAN 20) — `192.168.20.70`
   * **Destination:** MGMT (VLAN 10) & SERVICES (VLAN 110)

---

## 🔍 Verification & Testing Plan

1. **Internal RDP Test:** Test local RDP connectivity from administrative PC to `192.168.20.70:3389`.
2. **Guacamole Gateway Test:** Open Guacamole UI at `http://192.168.110.x:8085/guacamole` and initiate connection to Linux Mint. Verify smooth desktop rendering, audio, and responsiveness.
3. **Authentik MFA Challenge Test:** Navigate to public endpoint `https://remote.homelab-admin.me` in an Incognito browser session:
   * Verify redirect to `https://auth.homelab-admin.me`.
   * Confirm system prompts for credentials **plus MFA token (TOTP / YubiKey)**.
   * Confirm post-authentication redirect lands into Linux Mint desktop session.

---

## 📑 References & Related Documentation

- [[Network Overview]] — Homelab-Net Subnet & VLAN Mapping
- [[Class-C-Subnet-Schema-Recommendation]] — VLAN 20 Trusted Workstation IP allocations
- [[Authentik-Immich-OAuth2-OIDC-Setup-Guide-2026-07-31]] — Existing Authentik SSO infrastructure details
- [[Cloudflare-Tunnel-Setup]] — Cloudflare Ingress Tunnel configuration
