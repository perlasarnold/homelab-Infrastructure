# ─── WinRM / Provider auth ───────────────────────────────────────────────────
variable "winrm_username" {
  description = "Windows username with Hyper-V administrator rights."
  type        = string
  sensitive   = true
}

variable "winrm_password" {
  description = "Password for winrm_username."
  type        = string
  sensitive   = true
}

variable "winrm_cacert_path" {
  description = "Path to the PEM certificate exported by 01_enable_hyperv_winrm.ps1."
  type        = string
  default     = "C:\\Github\\hyperv-debian-terraform\\setup\\winrm_cacert.pem"
}

# ─── VM Configuration ────────────────────────────────────────────────────────
variable "vm_name" {
  description = "Display name of the Hyper-V VM."
  type        = string
  default     = "debian-server"
}

variable "vm_cpus" {
  description = "Number of virtual CPUs."
  type        = number
  default     = 2
}

variable "vm_memory_mb" {
  description = "Maximum RAM in megabytes (dynamic memory)."
  type        = number
  default     = 2048
}

variable "disk_size_gb" {
  description = "Size of the primary VHDX in gigabytes."
  type        = number
  default     = 40
}

variable "vhdx_dir" {
  description = "Directory where VHDX files are stored."
  type        = string
  default     = "C:\\Hyper-V"
}

variable "iso_path" {
  description = "Full path to the Debian installer ISO."
  type        = string
  default     = "C:\\ISOs\\debian-13-amd64-netinst.iso"
}

variable "network_switch" {
  description = "Hyper-V virtual switch name. 'Default Switch' = NAT with internet access."
  type        = string
  default     = "Default Switch"
}
