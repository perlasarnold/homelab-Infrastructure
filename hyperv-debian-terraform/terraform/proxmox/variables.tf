variable "proxmox_node" {
  description = "Proxmox node name (e.g., 'pve' — visible in Proxmox UI sidebar)."
  type        = string
  default     = "pve"
}

variable "vm_id" {
  description = "Proxmox VM ID for the new Debian VM."
  type        = number
  default     = 100
}

variable "template_vm_id" {
  description = "VM ID of the Debian 12 cloud-init template (created by install.sh)."
  type        = number
  default     = 9000
}

variable "vm_name" {
  description = "VM display name in Proxmox."
  type        = string
  default     = "debian-server"
}

variable "vm_cpus" {
  description = "Number of CPU cores."
  type        = number
  default     = 2
}

variable "vm_memory_mb" {
  description = "RAM in megabytes."
  type        = number
  default     = 2048
}

variable "disk_size_gb" {
  description = "Primary disk size in gigabytes."
  type        = number
  default     = 40
}

variable "storage_pool" {
  description = "Proxmox storage pool (e.g., 'local-lvm')."
  type        = string
  default     = "local-lvm"
}

variable "network_bridge" {
  description = "Proxmox network bridge (default vmbr0 = LAN)."
  type        = string
  default     = "vmbr0"
}

variable "vm_ip" {
  description = "Static IP for the VM. Leave empty string for DHCP."
  type        = string
  default     = ""   # empty = DHCP
}

variable "vm_cidr" {
  description = "CIDR prefix length for static IP (e.g., 24 for /24)."
  type        = number
  default     = 24
}

variable "vm_gateway" {
  description = "Default gateway for static IP."
  type        = string
  default     = "VLAN 1 [Gateway]"
}

variable "ssh_public_key" {
  description = "SSH public key injected via cloud-init. Store in DEBIAN_SSH_PUBLIC_KEY secret."
  type        = string
  sensitive   = true
}
