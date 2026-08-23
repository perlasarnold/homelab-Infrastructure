###############################################################################
# Proxmox Virtual Machines
# Node: Bulakan — All VMs managed via Terraform
#
# NOTE: Disk blocks are intentionally omitted here because these VMs
#       were created outside Terraform. We use lifecycle.ignore_changes
#       to prevent Terraform from destroying/recreating them.
#       For disk changes, use the Proxmox UI directly.
###############################################################################

# ---------------------------------------------------------------------------
# 201 — Perlas-W10  [RUNNING]
# ---------------------------------------------------------------------------
resource "proxmox_virtual_environment_vm" "perlas_w10" {
  node_name = var.proxmox_node
  vm_id     = 201
  name      = "Perlas-W10"
  on_boot   = true
  started   = true

  description = "Windows 10 desktop VM — daily driver"
  tags        = ["windows"]

  cpu {
    cores = 4
    type  = "host"
  }

  memory {
    dedicated = 8192
  }

  network_device {
    bridge = var.default_bridge
    model  = "virtio"
  }

  lifecycle {
    ignore_changes = all
  }
}

# ---------------------------------------------------------------------------
# 204 — Immich-UbuntuLTS  [RUNNING]
# ---------------------------------------------------------------------------
resource "proxmox_virtual_environment_vm" "immich_ubuntu" {
  node_name = var.proxmox_node
  vm_id     = 204
  name      = "Immich-UbuntuLTS"
  on_boot   = true
  started   = true

  description = "Ubuntu LTS VM — runs Immich photo management (self-hosted)"
  tags        = ["ubuntu", "photos", "immich"]

  cpu {
    cores = 4
    type  = "host"
  }

  memory {
    dedicated = 12288
  }

  network_device {
    bridge = var.default_bridge
    model  = "virtio"
  }

  lifecycle {
    ignore_changes = all
  }
}

# ---------------------------------------------------------------------------
# 202 — W11E  [STOPPED]
# ---------------------------------------------------------------------------
resource "proxmox_virtual_environment_vm" "w11e" {
  node_name   = var.proxmox_node
  vm_id       = 202
  name        = "W11E"
  started     = false
  description = "Windows 11 Enterprise VM (stopped)"
  tags        = ["windows"]

  cpu {
    cores = 4
    type  = "host"
  }

  memory {
    dedicated = 8192
  }

  network_device {
    bridge = var.default_bridge
    model  = "virtio"
  }

  lifecycle {
    ignore_changes = all
  }
}

# ---------------------------------------------------------------------------
# 203 — Bastion  [STOPPED]
# ---------------------------------------------------------------------------
resource "proxmox_virtual_environment_vm" "bastion" {
  node_name   = var.proxmox_node
  vm_id       = 203
  name        = "Bastion"
  started     = false
  description = "Bastion/jump host VM (stopped)"
  tags        = ["linux", "networking"]

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 2048
  }

  network_device {
    bridge = var.default_bridge
    model  = "virtio"
  }

  lifecycle {
    ignore_changes = all
  }
}

# ---------------------------------------------------------------------------
# 305 — Hack-Sonoma  [STOPPED]
# ---------------------------------------------------------------------------
resource "proxmox_virtual_environment_vm" "hack_sonoma" {
  node_name   = var.proxmox_node
  vm_id       = 305
  name        = "Hack-Sonoma"
  started     = false
  description = "macOS Sonoma Hackintosh VM (stopped)"
  tags        = ["macos"]

  cpu {
    cores = 4
    type  = "host"
  }

  memory {
    dedicated = 8192
  }

  network_device {
    bridge = var.default_bridge
    model  = "virtio"
  }

  lifecycle {
    ignore_changes = all
  }
}
