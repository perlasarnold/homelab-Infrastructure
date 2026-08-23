###############################################################################
# Input Variables — Proxmox
###############################################################################

variable "proxmox_endpoint" {
  description = "Full URL to the Proxmox API (include port 8006)"
  type        = string
  default     = "https://VLAN 1 [MGMT]:8006"
}

variable "proxmox_api_token" {
  description = "Proxmox API token in format USER@REALM!TOKENID=SECRET"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Name of the Proxmox node to deploy resources on"
  type        = string
  default     = "Bulakan"
}

variable "cebu_node" {
  description = "Name of the new Proxmox node"
  type        = string
  default     = "cebu"
}

variable "default_bridge" {
  description = "Default network bridge for containers and VMs"
  type        = string
  default     = "vmbr0"
}

variable "bulakan_datastore" {
  description = "Storage pool for Bulakan"
  type        = string
  default     = "Bulakan-ZFS"
}

variable "cebu_datastore" {
  description = "Storage pool for Cebu"
  type        = string
  default     = "cebu-zfs"
}

variable "lxc_template" {
  description = "LXC template for Bulakan containers"
  type        = string
  default     = "local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst"
}

variable "cebu_lxc_template" {
  description = "LXC template for Cebu containers"
  type        = string
  default     = "local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst"
}
