# 🚀 Dapitan GUI Torrent Box (Ubuntu + Google Remote Desktop) — Terraform Plan

> **Date:** 2026-07-24  
> **Objective:** Provision a dedicated Linux GUI Torrent Box VM (`torrent-box-dapitan` / VM 501) on Proxmox host `Dapitan` using Terraform IaaC (`bpg/proxmox`), accessible globally via **Google Remote Desktop (CRD)**. Active downloads land on a 128GB NVMe drive (`vm-fast`) to prevent HDD thrashing, with completed files auto-transferred to the 18TB ZFS HDD pool (`bulk18`).  
> **Target Host:** Proxmox Node `Dapitan` (`VLAN 1 (Mgmt)`)  
> **Maintainer:** Perlas  

---

## ⚡ TL;DR — Quick Start & Key Decisions

> [!IMPORTANT]
> **Safe Targeted Execution Command**  
> To deploy this VM without affecting any other existing homelab containers/VMs on Bulakan or Cebu, run:
> ```powershell
> cd /opt/homelab-infrastructure\terraform\proxmox
> terraform apply -target="proxmox_virtual_environment_vm.torrent_box_dapitan" -target="proxmox_virtual_environment_file.torrent_box_cloud_config"
> ```

- **VM Specs**: `torrent-box-dapitan` | VM ID `501` | Static IP **`VLAN 1 (Mgmt)/24`** | Host `dapitan` (`VLAN 1 (Mgmt)`)
- **OS & Remote Access**: Ubuntu 24.04 LTS + XFCE4 GUI + Google Remote Desktop (`chrome-remote-desktop`)
- **Hardware Specs**: 4 host CPU cores (`--cpu host`), 8 GB fixed RAM, VirtIO SCSI Single (`iothread=true`)
- **Storage Strategy**:
  - **NVMe `vm-fast` (128 GB)**: OS + Active Torrent downloads (`/var/downloads/active`) to prevent HDD thrashing.
  - **HDD `bulk18` (18 TB)**: Auto-move completed downloads (`/mnt/bulk18/completed`). Read-Only for media libraries.
- **Security Controls**: qBittorrent bound strictly to VPN interface (`tun0`), Proxmox VM Firewall enabled (`firewall=1`), Google 2FA PIN protection.

---

## 📖 Executive Summary & Context

To re-enable desktop downloading functionality on Proxmox node `Dapitan` while avoiding host resource contention, a dedicated lightweight **Ubuntu 24.04 LTS + XFCE4 GUI VM** was architected. 

Using **Google Remote Desktop (CRD)** provides high-framerate, secure remote desktop access from any browser or device without exposing inbound SSH/RDP ports to the public internet.

---

## 🔒 Security Implications & Mitigations

| Risk / Security Vector | Potential Impact | Technical Mitigation |
| :--- | :--- | :--- |
| **P2P IP Exposure** | Public IP address exposed in torrent swarms. | **VPN Network Interface Binding**: qBittorrent network interface is strictly locked to `tun0`/WireGuard (`Network Interface = tun0`). If VPN disconnects, torrent I/O immediately drops to 0 B/s (hardware kill-switch). |
| **Malware / Ransomware Isolation** | Untrusted torrent downloads executing malicious code. | **Read-Only Media Mounts**: `/mnt/bulk18/media-data` is mounted **Read-Only** (`ro`). Write access is restricted to `/mnt/bulk18/downloads`. ZFS atomic snapshots are enabled on `bulk18` for instant recovery. |
| **Google Remote Desktop Access** | Unauthorized remote access to VM desktop. | **Google 2FA & PIN Protection**: Remote session requires Google Account authentication backed by hardware 2FA and a local 6-digit PIN. |
| **Network Lateral Movement** | Compromised guest attempting LAN probes. | **Proxmox VM Firewall**: `firewall=1` is enforced on `net0` interface via Terraform. |

---

## ⚡ Performance Optimization Architecture

```
 ┌────────────────────────────────────────────────────────────────────────┐
 │                      Proxmox Host: Dapitan                             │
 │                                                                        │
 │  ┌──────────────────────────────────────────────────────────────────┐  │
 │  │ VM 501: torrent-box-dapitan (Ubuntu 24.04 + XFCE Desktop)        │  │
 │  │ Managed via Terraform (bpg/proxmox provider)                     │  │
 │  │                                                                  │  │
 │  │  • Remote Access: Google Remote Desktop (CRD) Host               │  │
 │  │  • Torrent Client: qBittorrent GUI (bound to VPN tun0)           │  │
 │  │  • Active Downloads Staging: /var/downloads/active (NVMe 128GB)   │  │
 │  └─────────────────┬───────────────────────────────┬────────────────┘  │
 │                    │                               │                   │
 │       Storage (NVMe)                       Storage (18TB ZFS HDD)     │
 │                    ▼                               ▼                   │
 │  ┌──────────────────────────────────┐   ┌───────────────────────────┐  │
 │  │ Pool: vm-fast                    │   │ Pool: bulk18              │  │
 │  │ • 128GB OS & Active Torrent OS   │   │ • bulk18/media-data (RO)  │  │
 │  │   piece writes (High IOPS)       │   │ • bulk18/downloads (RW)   │  │
 │  └──────────────────────────────────┘   └───────────────────────────┘  │
 └────────────────────────────────────────────────────────────────────────┘
```

1. **NVMe Active Download Staging (`vm-fast`)**: Torrenting involves hundreds of simultaneous random piece reads/writes. Torrenting directly onto a mechanical HDD (`bulk18`) saturates its ~150 IOPS limit, causing torrent stalls and freezing Jellyfin/Immich services. Active downloads run entirely on `/var/downloads/active` (128GB NVMe).
2. **Sequential Move to HDD (`bulk18`)**: qBittorrent auto-moves completed files to `/mnt/bulk18/completed`. This turns random piece writes into a fast **sequential stream**, preserving HDD health and performance.
3. **VirtIO Disk & TRIM Flags**: `discard = "on"`, `ssd = true`, `cache = "writeback"`, and `iothread = true` pass NVMe TRIM commands to ZFS to prevent SSD space bloat.
4. **CPU Passthrough**: `--cpu host` with 4 dedicated cores allows real-time VP8/VP9 video encoding (Google Remote Desktop) and VPN WireGuard encryption without CPU lag.

---

## 🛠️ Terraform Infrastructure as Code

The Terraform configuration file is saved at:
* **HCL Source File:** [`02-Proxmox/Terraform/dapitan_torrent_box.tf`](file:////opt/homelab-infrastructure/02-Proxmox/Terraform/dapitan_torrent_box.tf)
* **Active Directory File:** [`terraform/proxmox/dapitan_torrent_box.tf`](file:////opt/homelab-infrastructure/terraform/proxmox/dapitan_torrent_box.tf)

### Key HCL Code Highlights:

```hcl
resource "proxmox_virtual_environment_vm" "torrent_box_dapitan" {
  node_name = "dapitan"
  vm_id     = 501
  name      = "torrent-box-dapitan"
  tags      = ["torrent", "ubuntu", "gui", "media"]

  on_boot = true
  started = true

  cpu {
    cores = 4
    type  = "host"
  }

  memory {
    dedicated = 8192
  }

  scsi_hardware = "virtio-scsi-single"
  disk {
    datastore_id = "vm-fast"
    interface    = "scsi0"
    size         = 128
    discard      = "on"
    ssd          = true
    cache        = "writeback"
    iothread     = true
  }

  network_device {
    bridge   = "vmbr0"
    model    = "virtio"
    firewall = true
  }

  agent {
    enabled = true
  }

  initialization {
    ip_config {
      ipv4 {
        address = "VLAN 1 (Mgmt)/24"
        gateway = "VLAN 1 [Gateway]"
      }
    }
    user_data_file_id = proxmox_virtual_environment_file.torrent_box_cloud_config.id
  }
}
```

---

## 🚀 Execution & Deployment Steps

### Step 1: Deploy Infrastructure via Terraform
Execute the Terraform deployment from your management workstation:
```powershell
cd /opt/homelab-infrastructure\terraform\proxmox
terraform init
terraform plan
terraform apply
```

### Step 2: One-Time Google Remote Desktop Link
1. Open **[remotedesktop.google.com/headless](https://remotedesktop.google.com/headless)** in your Web Browser.
2. Click **Set up another computer** -> **Begin** -> **Next** -> **Authorize**.
3. Copy the generated Linux authorization command snippet.
4. SSH into the VM:
   ```bash
   ssh ubuntu@VLAN 1 (Mgmt)
   ```
5. Paste the command snippet and set your 6-digit PIN.

### Step 3: Connect to GUI & Configure qBittorrent
1. Open Chrome or the Google Remote Desktop app on any device, select `torrent-box-dapitan`, enter your PIN, and view the XFCE Linux desktop.
2. Open qBittorrent GUI.
3. Under **Options -> Connection -> Network Interface**, select your VPN interface (`tun0`/WireGuard).
4. Under **Options -> Downloads**:
   - *Default Save Path:* `/mnt/bulk18/completed`
   - *Keep incomplete torrents in:* `/var/downloads/active` (NVMe)

---

## 🧪 Verification Plan

1. **Terraform Apply Verification**: Confirm `terraform apply` completes with zero errors and VM 201 shows `running` in Proxmox UI.
2. **QEMU Guest Agent**: Verify IP `VLAN 1 (Mgmt)` is reported under VM Summary.
3. **CRD Remote GUI**: Connect via Google Remote Desktop and verify smooth 60fps interaction.
4. **VPN Kill-Switch Test**: Disconnect VPN during an active test download (e.g. Ubuntu ISO torrent) and verify transfer rate drops to 0 B/s immediately.
5. **Disk IOPS & Auto-Move**: Verify active download pieces hit NVMe `/var/downloads/active` without disk queue bottleneck, and completed files transfer cleanly to `/mnt/bulk18/completed`.

---

## 📑 References
- Proxmox Provider Documentation: [bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox/latest/docs)
- Google Remote Desktop Linux Setup: [remotedesktop.google.com/headless](https://remotedesktop.google.com/headless)
- Dapitan Storage Architecture: [`06-Guides/OptiPlex-Proxmox-Direct-Attached-Storage-Plan-2026-07-22.md`](file:////opt/homelab-infrastructure/06-Guides/OptiPlex-Proxmox-Direct-Attached-Storage-Plan-2026-07-22.md)
