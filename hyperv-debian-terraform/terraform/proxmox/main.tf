terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66"
    }
  }
}

# ─── Provider: Proxmox API ────────────────────────────────────────────────────
# Credentials via environment variables (set by GitHub Actions secrets):
#   PROXMOX_VE_ENDPOINT   = https://<HOST>:8006
#   PROXMOX_VE_API_TOKEN  = root@pam!terraform=<SECRET>
provider "proxmox" {
  insecure = true   # set false if you have a valid TLS cert on Proxmox
}

# ─── Debian VM (cloned from cloud-init template 9000) ─────────────────────────
resource "proxmox_virtual_environment_vm" "debian" {
  name      = var.vm_name
  node_name = var.proxmox_node
  vm_id     = var.vm_id

  description = "Managed by Terraform + GitHub Actions"
  tags        = ["terraform", "homelab", "debian"]

  # Clone from the Debian 12 cloud-init template created by install.sh
  clone {
    vm_id   = var.template_vm_id   # 9000 by default
    full    = true
  }

  cpu {
    cores   = var.vm_cpus
    type    = "x86-64-v2-AES"   # modern CPU flags, compatible with Debian
  }

  memory {
    dedicated = var.vm_memory_mb
    floating  = var.vm_memory_mb   # ballooning max
  }

  disk {
    datastore_id = var.storage_pool
    size         = var.disk_size_gb
    interface    = "scsi0"
    iothread     = true
    discard      = "on"
    file_format  = "raw"
  }

  network_device {
    bridge = var.network_bridge   # vmbr0 = default bridged network
    model  = "virtio"
  }

  # ── Cloud-init: auto-configure on first boot ─────────────────────────────────
  initialization {
    datastore_id = var.storage_pool

    ip_config {
      ipv4 {
        address = var.vm_ip == "" ? "dhcp" : "${var.vm_ip}/${var.vm_cidr}"
        gateway = var.vm_ip == "" ? null : var.vm_gateway
      }
    }

    user_account {
      username = "debian"
      keys     = [var.ssh_public_key]   # from GitHub Secret
      password = null                    # key-only auth
    }

    dns {
      domain  = "homelab.local"
      servers = ["8.8.8.8", "1.1.1.1"]
    }
  }

  # Enable QEMU guest agent (installed via cloud-init userdata)
  agent {
    enabled = true
  }

  operating_system {
    type = "l26"   # Linux kernel 2.6+
  }

  # Prevent accidental destruction — remove this for full IaC lifecycle control
  lifecycle {
    prevent_destroy = false
  }
}
