###############################################################################
# Cebu Node Resources (VLAN 1 [MGMT])
# VLAN & Subnet Segmented Deployment
# Architecture: Management (VLAN 10), Services (VLAN 110), DMZ (VLAN 120)
###############################################################################

# ---------------------------------------------------------------------------
# Public DMZ / External — cloudflared-cebu (CT 404)
# ---------------------------------------------------------------------------
module "cloudflared_cebu" {
  source       = "./modules/lxc"
  node_name    = var.cebu_node
  vm_id        = 404
  hostname     = "cloudflared-cebu"
  description  = "Cloudflare tunnel client (Cebu) — Secondary Active"
  tags         = ["dmz", "tunnel", "external"]
  template_id  = var.cebu_lxc_template
  datastore_id = var.cebu_datastore
  memory       = 512
  cores        = 1
  disk_size    = 8
  vlan_id      = 120
  ipv4_address = "VLAN 120 (DMZ)/24"
  gateway      = "VLAN 120 (DMZ)"
}

# ---------------------------------------------------------------------------
# Public DMZ / External — npm-cebu (CT 105)
# ---------------------------------------------------------------------------
module "npm_cebu" {
  source       = "./modules/lxc"
  node_name    = var.cebu_node
  vm_id        = 105
  hostname     = "npm-cebu"
  description  = "Nginx Proxy Manager (Cebu) — Secondary Reverse Proxy"
  tags         = ["dmz", "proxy", "external"]
  template_id  = var.cebu_lxc_template
  datastore_id = var.cebu_datastore
  memory       = 1024
  cores        = 2
  disk_size    = 16
  vlan_id      = 120
  ipv4_address = "VLAN 120 (DMZ)/24"
  gateway      = "VLAN 120 (DMZ)"
}

# ---------------------------------------------------------------------------
# DNS Redundancy — pihole-cebu (CT 401)
# ---------------------------------------------------------------------------
module "pihole_cebu" {
  source       = "./modules/lxc"
  node_name    = var.cebu_node
  vm_id        = 401
  hostname     = "pihole-cebu"
  description  = "Secondary Pi-hole for DNS redundancy (Cebu)"
  tags         = ["dns", "networking", "services"]
  template_id  = var.cebu_lxc_template
  datastore_id = var.cebu_datastore
  memory       = 512
  cores        = 2
  disk_size    = 8
  vlan_id      = 110
  ipv4_address = "192.168.42.5/24" 
  gateway      = "192.168.42.1"
}

# ---------------------------------------------------------------------------
# Media Server — jellyfin-cebu (CT 416)
# ---------------------------------------------------------------------------
module "jellyfin_cebu" {
  source       = "./modules/lxc"
  node_name    = var.cebu_node
  vm_id        = 416
  hostname     = "jellyfin-cebu"
  description  = "Jellyfin media server (Cebu)"
  tags         = ["media", "services"]
  template_id  = var.cebu_lxc_template
  datastore_id = var.cebu_datastore
  memory       = 4096
  cores        = 4
  disk_size    = 32
  vlan_id      = 110
  ipv4_address = "192.168.42.41/24"
  gateway      = "192.168.42.1"
  nesting      = true
}

# ---------------------------------------------------------------------------
# Media Server — plex-cebu (CT 405 / 109)
# ---------------------------------------------------------------------------
module "plex_cebu" {
  source       = "./modules/lxc"
  node_name    = var.cebu_node
  vm_id        = 405
  hostname     = "plex-cebu"
  description  = "Plex Media Server (Cebu)"
  tags         = ["media", "services"]
  template_id  = var.cebu_lxc_template
  datastore_id = var.cebu_datastore
  memory       = 4096
  cores        = 4
  disk_size    = 40
  vlan_id      = 110
  ipv4_address = "192.168.42.215/24" 
  gateway      = "192.168.42.1"
  nesting      = true
}

# ---------------------------------------------------------------------------
# Arr Stack — arr-stack-cebu (CT 417)
# ---------------------------------------------------------------------------
module "arr_stack_cebu" {
  source       = "./modules/lxc"
  node_name    = var.cebu_node
  vm_id        = 417
  hostname     = "arr-stack-cebu"
  description  = "Arr Stack (Sonarr, Radarr, Bazarr, Jackett, Wizarr)"
  tags         = ["media", "services", "arr-stack"]
  template_id  = var.cebu_lxc_template
  datastore_id = var.cebu_datastore
  memory       = 2048
  cores        = 2
  disk_size    = 32
  vlan_id      = 110
  ipv4_address = "192.168.42.42/24"
  gateway      = "192.168.42.1"
  nesting      = true
  mount_points = [
    {
      volume = "/mnt/truenas/seagate/share"
      path   = "/mnt/truenas/seagate/share"
    }
  ]
}
