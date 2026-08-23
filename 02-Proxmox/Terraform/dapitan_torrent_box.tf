###############################################################################
# GUI Torrent Box — Dapitan Node (Proxmox VE LXC)
# CT ID: 501 | Hostname: torrent-box-dapitan
# OS: Ubuntu 24.04 LTS + XFCE4 Desktop + Google Remote Desktop (CRD)
# Date: 2026-07-24
###############################################################################

resource "proxmox_virtual_environment_container" "torrent_box_dapitan" {
  node_name    = "Dapitan"
  vm_id        = 501
  description  = "GUI Torrent Box (Ubuntu 24.04 + XFCE + Google Remote Desktop) — Active downloads on NVMe vm-fast"
  tags         = ["torrent", "ubuntu", "gui", "media"]
  started      = true
  unprivileged = true

  cpu {
    cores = 4
  }

  memory {
    dedicated = 8192
  }

  operating_system {
    type             = "ubuntu"
    template_file_id = "local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
  }

  initialization {
    hostname = "torrent-box-dapitan"

    ip_config {
      ipv4 {
        address = "192.168.1.71/24"
        gateway = "192.168.1.1"
      }
    }
  }

  network_interface {
    name   = "eth0"
    bridge = "vmbr0"
  }

  features {
    nesting = true
  }

  disk {
    datastore_id = "vm-fast"
    size         = 128
  }
}
