###############################################################################
# Proxmox LXC Containers
# Node: Bulakan — Refactored to use modules on 2026-05-14
###############################################################################

module "wireguard" {
  source       = "./modules/lxc"
  node_name    = var.proxmox_node
  vm_id        = 101
  hostname     = "wireguard"
  description  = "WireGuard VPN gateway — proxmox-helper-scripts"
  tags         = ["proxmox-helper-scripts"]
  template_id  = var.lxc_template
  datastore_id = var.bulakan_datastore
  disk_size    = 4
  nesting      = true
}

module "prowlarr" {
  source       = "./modules/lxc"
  node_name    = var.proxmox_node
  vm_id        = 103
  hostname     = "prowlarr"
  description  = "Prowlarr indexer manager — proxmox-helper-scripts"
  tags         = ["proxmox-helper-scripts", "arr-stack"]
  template_id  = var.lxc_template
  datastore_id = var.bulakan_datastore
  ipv4_address = "192.168.1.53/24"
  gateway      = "192.168.1.1"
  memory       = 1024
  cores        = 2
}

module "plex" {
  source       = "./modules/lxc"
  node_name    = var.proxmox_node
  vm_id        = 104
  hostname     = "plex"
  description  = "Plex Media Server — proxmox-helper-scripts"
  tags         = ["proxmox-helper-scripts", "media"]
  template_id  = var.lxc_template
  datastore_id = var.bulakan_datastore
  memory       = 2048
  cores        = 2
  nesting      = true
}

module "radarr" {
  source       = "./modules/lxc"
  node_name    = var.proxmox_node
  vm_id        = 105
  hostname     = "radarr"
  description  = "Radarr movie manager — proxmox-helper-scripts"
  tags         = ["proxmox-helper-scripts", "arr-stack"]
  template_id  = var.lxc_template
  datastore_id = var.bulakan_datastore
  memory       = 2048
  cores        = 2
}

module "sonarr" {
  source       = "./modules/lxc"
  node_name    = var.proxmox_node
  vm_id        = 106
  hostname     = "sonarr"
  description  = "Sonarr TV series manager — proxmox-helper-scripts"
  tags         = ["proxmox-helper-scripts", "arr-stack"]
  template_id  = var.lxc_template
  datastore_id = var.bulakan_datastore
  memory       = 4096
  cores        = 2
}

module "bazarr" {
  source       = "./modules/lxc"
  node_name    = var.proxmox_node
  vm_id        = 107
  hostname     = "bazarr"
  description  = "Bazarr subtitle manager — proxmox-helper-scripts"
  tags         = ["proxmox-helper-scripts", "arr-stack"]
  template_id  = var.lxc_template
  datastore_id = var.bulakan_datastore
  memory       = 1024
  cores        = 2
}

module "jackett" {
  source       = "./modules/lxc"
  node_name    = var.proxmox_node
  vm_id        = 108
  hostname     = "jackett"
  description  = "Jackett tracker proxy — proxmox-helper-scripts"
  tags         = ["proxmox-helper-scripts", "arr-stack"]
  template_id  = var.lxc_template
  datastore_id = var.bulakan_datastore
  memory       = 1024
  cores        = 1
}

module "audiobookshelf" {
  source       = "./modules/lxc"
  node_name    = var.proxmox_node
  vm_id        = 109
  hostname     = "audiobookshelf"
  description  = "Audiobookshelf audiobook server — proxmox-helper-scripts"
  tags         = ["proxmox-helper-scripts", "media"]
  template_id  = var.lxc_template
  datastore_id = var.bulakan_datastore
  memory       = 2048
  cores        = 2
}

module "photoprism" {
  source       = "./modules/lxc"
  node_name    = var.proxmox_node
  vm_id        = 111
  hostname     = "photoprism"
  description  = "PhotoPrism photo library — proxmox-helper-scripts"
  tags         = ["proxmox-helper-scripts", "photos"]
  template_id  = var.lxc_template
  datastore_id = var.bulakan_datastore
  memory       = 4096
  cores        = 2
}

module "transmission" {
  source       = "./modules/lxc"
  node_name    = var.proxmox_node
  vm_id        = 112
  hostname     = "transmission"
  description  = "Transmission BitTorrent client — proxmox-helper-scripts"
  tags         = ["proxmox-helper-scripts", "downloads"]
  template_id  = var.lxc_template
  datastore_id = var.bulakan_datastore
  memory       = 2048
  cores        = 2
}

module "heimdall_dashboard" {
  source       = "./modules/lxc"
  node_name    = var.proxmox_node
  vm_id        = 115
  hostname     = "heimdall-dashboard"
  description  = "Heimdall application dashboard — proxmox-helper-scripts"
  tags         = ["proxmox-helper-scripts", "dashboard"]
  template_id  = var.lxc_template
  datastore_id = var.bulakan_datastore
  memory       = 512
  cores        = 1
  disk_size    = 4
}

module "jellyfin" {
  source       = "./modules/lxc"
  node_name    = var.proxmox_node
  vm_id        = 116
  hostname     = "jellyfin"
  description  = "Jellyfin open-source media server"
  tags         = ["media"]
  template_id  = var.lxc_template
  datastore_id = var.bulakan_datastore
  memory       = 4096
  cores        = 2
  ipv4_address = "192.168.1.52/24"
  gateway      = "192.168.1.1"
  nesting      = true
}

module "pihole" {
  source       = "./modules/lxc"
  node_name    = var.proxmox_node
  vm_id        = 301
  hostname     = "pihole"
  description  = "Pi-hole network-wide DNS ad-blocker"
  tags         = ["dns", "networking"]
  template_id  = var.lxc_template
  datastore_id = var.bulakan_datastore
  memory       = 512
  cores        = 2
  disk_size    = 4
  ipv4_address = "192.168.1.4/24"
  gateway      = "192.168.1.1"
}

module "cloudflared" {
  source       = "./modules/lxc"
  node_name    = var.proxmox_node
  vm_id        = 304
  hostname     = "cloudflared"
  description  = "Cloudflared tunnel daemon — proxmox-helper-scripts"
  tags         = ["proxmox-helper-scripts", "networking"]
  template_id  = var.lxc_template
  datastore_id = var.bulakan_datastore
  memory       = 512
  cores        = 2
  disk_size    = 4
}

module "netbootxyz" {
  source       = "./modules/lxc"
  node_name    = var.proxmox_node
  vm_id        = 118
  hostname     = "netbootxyz"
  description  = "netboot.xyz - PXE network boot server"
  tags         = ["proxmox-helper-scripts", "networking", "pxe"]
  template_id  = var.lxc_template
  datastore_id = var.bulakan_datastore
  memory       = 1024
  cores        = 2
  disk_size    = 16
  ipv4_address = "192.168.1.54/24"
  gateway      = "192.168.1.1"
}

# STOPPED CONTAINERS

module "qbittorrent" {
  source       = "./modules/lxc"
  node_name    = var.proxmox_node
  vm_id        = 100
  hostname     = "qbittorrent"
  description  = "qBittorrent download client (stopped)"
  tags         = ["downloads", "yarrr"]
  template_id  = var.lxc_template
  datastore_id = var.bulakan_datastore
  memory       = 1024
  cores        = 2
  started      = false
}

module "nginxproxymanager" {
  source       = "./modules/lxc"
  node_name    = var.proxmox_node
  vm_id        = 102
  hostname     = "nginxproxymanager"
  description  = "Nginx Proxy Manager (active)"
  tags         = ["proxmox-helper-scripts", "networking"]
  template_id  = var.lxc_template
  datastore_id = var.bulakan_datastore
  memory       = 2048
  cores        = 2
  ipv4_address = "192.168.1.51/24"
  gateway      = "192.168.1.1"
  started      = true
}

module "freeipa" {
  source       = "./modules/lxc"
  node_name    = var.proxmox_node
  vm_id        = 110
  hostname     = "freeipa"
  description  = "FreeIPA centralized identity management"
  tags         = ["identity", "networking"]
  template_id  = var.lxc_template
  datastore_id = var.bulakan_datastore
  memory       = 4096
  cores        = 2
  ipv4_address = "192.168.1.50/24"
  gateway      = "192.168.1.1"
  nesting      = true
}

module "booklore" {
  source       = "./modules/lxc"
  node_name    = var.proxmox_node
  vm_id        = 117
  hostname     = "booklore"
  description  = "Booklore ebook / library manager (stopped)"
  tags         = ["books", "library"]
  template_id  = var.lxc_template
  datastore_id = var.bulakan_datastore
  memory       = 1024
  cores        = 2
  started      = false
}

module "openwrt" {
  source       = "./modules/lxc"
  node_name    = var.proxmox_node
  vm_id        = 302
  hostname     = "openwrt"
  description  = "OpenWrt virtual router (stopped)"
  tags         = ["networking"]
  template_id  = var.lxc_template
  datastore_id = var.bulakan_datastore
  memory       = 256
  cores        = 1
  disk_size    = 2
  started      = false
}
