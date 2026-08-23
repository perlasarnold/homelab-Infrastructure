###############################################################################
# Input Variables — Unraid Docker
###############################################################################

variable "unraid_ip" {
  description = "IP address of the Unraid server"
  type        = string
  default     = "VLAN 1 (Management)"
}

variable "docker_port" {
  description = "TCP port for Docker API on Unraid (default 2375 unencrypted)"
  type        = number
  default     = 2375
}

variable "appdata_path" {
  description = "Base path for Docker appdata on Unraid"
  type        = string
  default     = "/mnt/user/appdata"
}

variable "media_path" {
  description = "Path to main media share on Unraid"
  type        = string
  default     = "/mnt/user/PlexMedia"
}

variable "downloads_path" {
  description = "Path to downloads share on Unraid"
  type        = string
  default     = "/mnt/user/downloads"
}
