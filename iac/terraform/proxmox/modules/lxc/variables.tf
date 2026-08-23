variable "node_name" {
  type        = string
  description = "The name of the Proxmox node"
}

variable "vm_id" {
  type        = number
  description = "The ID of the LXC container"
}

variable "hostname" {
  type        = string
  description = "The hostname of the container"
}

variable "description" {
  type        = string
  default     = ""
  description = "Description for the container"
}

variable "tags" {
  type        = list(string)
  default     = []
  description = "Tags for the container"
}

variable "cores" {
  type        = number
  default     = 1
}

variable "memory" {
  type        = number
  default     = 512
  description = "Memory in MB"
}

variable "template_id" {
  type        = string
  description = "The template file ID"
}

variable "datastore_id" {
  type        = string
  description = "The storage pool ID"
}

variable "disk_size" {
  type        = number
  default     = 8
  description = "Disk size in GB"
}

variable "bridge" {
  type        = string
  default     = "vmbr0"
}

variable "vlan_id" {
  type        = number
  default     = null
  description = "Optional VLAN tag ID for the network interface"
}

variable "started" {
  type    = bool
  default = true
}

variable "nesting" {
  type    = bool
  default = false
}

variable "unprivileged" {
  type    = bool
  default = true
}

variable "ipv4_address" {
  type        = string
  default     = "dhcp"
  description = "IPv4 address (e.g. VLAN 1 (Management)/24) or 'dhcp'"
}

variable "gateway" {
  type        = string
  default     = ""
  description = "Gateway for static IP"
}

variable "mount_points" {
  type = list(object({
    volume = string
    path   = string
  }))
  default     = []
  description = "Optional list of bind mount points (host path -> container path)"
}
