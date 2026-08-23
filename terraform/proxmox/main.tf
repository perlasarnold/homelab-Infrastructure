###############################################################################
# Proxmox Terraform Configuration
# Node: Bulakan (VLAN 1 [MGMT]) · PVE 8.4.14
# Provider: bpg/proxmox
###############################################################################

terraform {
  required_version = ">= 1.5"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.76"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint   # e.g. "https://VLAN 1 [MGMT]:8006"
  api_token = var.proxmox_api_token  # e.g. "root@pam!terraform=xxxxxxxx-..."
  insecure  = true                   # skip TLS verification (self-signed cert)
}
