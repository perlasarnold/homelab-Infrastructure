###############################################################################
# Linux Mint Desktop Jump Box — Dapitan Node (Proxmox VE VM)
# VM ID: 505 | Hostname: mint-desktop-dapitan
# OS: Linux Mint 22 Cinnamon 64-bit
# Network: VLAN 20 (TRUSTED) — 192.168.20.70/24
# Storage: 128 GB on Dapitan ZFS NVMe/SSD pool (vm-fast)
# Maintainer: Homelab Admin
# Date: 2026-08-01
###############################################################################

resource "proxmox_virtual_environment_vm" "mint_desktop_dapitan" {
  node_name     = "Dapitan"
  vm_id         = 505
  name          = "mint-desktop-dapitan"
  description   = "Linux Mint 22 Remote Desktop Jump Box on Dapitan Node (128GB disk on vm-fast, VLAN 20 TRUSTED)"
  tags          = ["linux", "mint", "desktop", "remote-access", "dapitan"]
  on_boot       = true
  started       = true
  scsi_hardware = "virtio-scsi-single"

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

  # Ignore CD-ROM media changes after OS installation ejects ISO
  lifecycle {
    ignore_changes = [
      cdrom
    ]
  }
}
