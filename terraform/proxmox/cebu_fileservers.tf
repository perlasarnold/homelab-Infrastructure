###############################################################################
# Cebu File Server Containers
#
# NOTE: Bind mounts are NOT configured via Terraform because the Proxmox API
#       requires root@pam (not API tokens) for bind mount type=bind.
#       Bind mounts are added post-deploy via:
#         pct set 402 --mp0 /das-18tb-1,mp=/mnt/storage
#         pct set 403 --mp0 /das-18tb-1,mp=/mnt/storage
###############################################################################

# TurnKey FileServer (LXC 402)
module "fileserver" {
  source       = "./modules/lxc"
  node_name    = var.cebu_node
  vm_id        = 402
  hostname     = "fileserver"
  description  = "TurnKey FileServer — High-speed SMB storage (homelab-admin user)"
  tags         = ["storage", "infrastructure"]
  template_id  = "local:vztmpl/debian-12-turnkey-fileserver_18.0-1_amd64.tar.gz"
  datastore_id = var.cebu_datastore
  memory       = 1024
  cores        = 2
  disk_size    = 8
  unprivileged = false # Privileged required for SMB sharing
  # mount_points added manually post-deploy via SSH (see NOTE above)
}

# CasaOS (LXC 403)
module "casaos" {
  source       = "./modules/lxc"
  node_name    = var.cebu_node
  vm_id        = 403
  hostname     = "casaos"
  description  = "CasaOS — Home Cloud Dashboard and Media Hub"
  tags         = ["storage", "dashboard"]
  template_id  = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
  datastore_id = var.cebu_datastore
  memory       = 2048
  cores        = 2
  disk_size    = 16
  unprivileged = false # Privileged required for bind-mount access
  nesting      = true
  # mount_points added manually post-deploy via SSH (see NOTE above)
}
