###############################################################################
# Cebu Node Resources (192.168.1.26)
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
  ipv4_address = "192.168.120.7/24"
  gateway      = "192.168.120.1"
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
  ipv4_address = "192.168.120.210/24"
  gateway      = "192.168.120.1"
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

# ---------------------------------------------------------------------------
# Security — fail2ban-cebu (CT 406) + fail2ban-dashboard
# ---------------------------------------------------------------------------
module "fail2ban_cebu" {
  source       = "./modules/lxc"
  node_name    = var.cebu_node
  vm_id        = 406
  hostname     = "fail2ban-cebu"
  description  = "fail2ban IPS + dashboard — SSH, NPM, Authentik & Wazuh log monitoring"
  tags         = ["security", "secops", "fail2ban"]
  template_id  = var.cebu_lxc_template
  datastore_id = var.cebu_datastore
  memory       = 512
  cores        = 1
  disk_size    = 4
  vlan_id      = 10
  ipv4_address = "192.168.10.50/24"
  gateway      = "192.168.10.1"
  unprivileged = true
}

# ---------------------------------------------------------------------------
# Networking — tailscale-cebu (CT 407)
# ---------------------------------------------------------------------------
module "tailscale_cebu" {
  source       = "./modules/lxc"
  node_name    = var.cebu_node
  vm_id        = 407
  hostname     = "tailscale-cebu"
  description  = "Tailscale subnet router + exit node — OAuth client, all homelab subnets"
  tags         = ["networking", "vpn", "tailscale"]
  template_id  = var.cebu_lxc_template
  datastore_id = var.cebu_datastore
  memory       = 512
  cores        = 1
  disk_size    = 4
  vlan_id      = 1
  ipv4_address = "192.168.1.246/24"
  gateway      = "192.168.1.1"
  unprivileged = true
  nesting      = true
}

# ---------------------------------------------------------------------------
# Observability — grafana-cebu (CT 418)
# ---------------------------------------------------------------------------
module "grafana_cebu" {
  source       = "./modules/lxc"
  node_name    = var.cebu_node
  vm_id        = 418
  hostname     = "grafana-cebu"
  description  = "Grafana observability dashboard — grafana.perlasarnold.me"
  tags         = ["monitoring", "observability", "services"]
  template_id  = var.cebu_lxc_template
  datastore_id = var.cebu_datastore
  memory       = 2048
  cores        = 2
  disk_size    = 16
  vlan_id      = 110
  ipv4_address = "192.168.110.60/24"
  gateway      = "192.168.110.1"
  unprivileged = true
}

# ---------------------------------------------------------------------------
# Observability — uptime-kuma-cebu (CT 419)
# ---------------------------------------------------------------------------
module "uptime_kuma_cebu" {
  source       = "./modules/lxc"
  node_name    = var.cebu_node
  vm_id        = 419
  hostname     = "uptime-kuma-cebu"
  description  = "Uptime Kuma service monitor (Docker) — kuma.perlasarnold.me"
  tags         = ["monitoring", "uptime", "services"]
  template_id  = var.cebu_lxc_template
  datastore_id = var.cebu_datastore
  memory       = 1024
  cores        = 1
  disk_size    = 10
  vlan_id      = 110
  ipv4_address = "192.168.110.61/24"
  gateway      = "192.168.110.1"
  unprivileged = true
  nesting      = true
}

