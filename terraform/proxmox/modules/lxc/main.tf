terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.76"
    }
  }
}

resource "proxmox_virtual_environment_container" "this" {
  node_name   = var.node_name
  vm_id       = var.vm_id
  description = var.description
  tags        = var.tags
  started     = var.started
  unprivileged = var.unprivileged

  cpu {
    cores = var.cores
  }

  memory {
    dedicated = var.memory
  }

  operating_system {
    type             = "unmanaged"
    template_file_id = var.template_id
  }

  initialization {
    hostname = var.hostname
    
    dynamic "ip_config" {
      for_each = var.ipv4_address != "dhcp" ? [1] : []
      content {
        ipv4 {
          address = var.ipv4_address
          gateway = var.gateway
        }
      }
    }
  }

  network_interface {
    name    = "eth0"
    bridge  = var.bridge
    vlan_id = var.vlan_id
  }

  dynamic "features" {
    for_each = var.nesting ? [1] : []
    content {
      nesting = true
    }
  }

  disk {
    datastore_id = var.datastore_id
    size         = var.disk_size
  }

  dynamic "mount_point" {
    for_each = var.mount_points
    content {
      volume = mount_point.value.volume
      path   = mount_point.value.path
    }
  }

  lifecycle {
    ignore_changes = [
      operating_system
    ]
  }
}

output "id" {
  value = proxmox_virtual_environment_container.this.id
}

output "vm_id" {
  value = proxmox_virtual_environment_container.this.vm_id
}
