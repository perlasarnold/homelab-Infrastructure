# ==============================================================================
# UniFi Network Foundation Infrastructure as Code (Terraform)
# Architecture: Class C Subnets (VLAN 10, 20, 30, 110, 120)
# Target Hardware: UniFi Cloud Gateway Max (UCG Max) & USW Pro Max 16
# Maintainer: Homelab Admin
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    unifi = {
      source  = "paultyng/unifi"
      version = "~> 0.41.0"
    }
  }
}

provider "unifi" {
  api_url        = var.unifi_api_url
  username       = var.unifi_username
  password       = var.unifi_password
  site           = var.unifi_site
  allow_insecure = var.unifi_allow_insecure
}

# ------------------------------------------------------------------------------
# 1. Virtual Networks (Class C VLAN Subnets)
# ------------------------------------------------------------------------------

resource "unifi_network" "mgmt" {
  name          = "MGMT"
  purpose       = "corporate"
  vlan_id       = 10
  subnet        = var.vlan_mgmt_cidr
  dhcp_start    = "VLAN 10 (SecOps)"
  dhcp_stop     = "VLAN 10 (SecOps)"
  dhcp_enabled  = true
  domain_name   = "mgmt.homelab.internal"
}

resource "unifi_network" "trusted" {
  name          = "TRUSTED"
  purpose       = "corporate"
  vlan_id       = 20
  subnet        = var.vlan_trusted_cidr
  dhcp_start    = "VLAN 20 (Trusted)"
  dhcp_stop     = "VLAN 20 (Trusted)"
  dhcp_enabled  = true
  domain_name   = "trusted.homelab.internal"
}

resource "unifi_network" "iot" {
  name          = "IOT"
  purpose       = "corporate"
  vlan_id       = 30
  subnet        = var.vlan_iot_cidr
  dhcp_start    = "192.168.30.100"
  dhcp_stop     = "192.168.30.249"
  dhcp_enabled  = true
  domain_name   = "iot.homelab.internal"
}

resource "unifi_network" "services" {
  name          = "SERVICES"
  purpose       = "corporate"
  vlan_id       = 110
  subnet        = var.vlan_services_cidr
  dhcp_start    = "VLAN 110 (Services)"
  dhcp_stop     = "VLAN 110 (Services)"
  dhcp_enabled  = true
  domain_name   = "services.homelab.internal"
}

resource "unifi_network" "dmz" {
  name          = "DMZ"
  purpose       = "corporate"
  vlan_id       = 120
  subnet        = var.vlan_dmz_cidr
  dhcp_start    = "VLAN 120 (DMZ)"
  dhcp_stop     = "VLAN 120 (DMZ)"
  dhcp_enabled  = true
  domain_name   = "dmz.homelab.internal"
}

# ------------------------------------------------------------------------------
# 2. Firewall Groups (IP & Port Groups)
# ------------------------------------------------------------------------------

resource "unifi_firewall_group" "rfc1918_private_subnets" {
  name = "RFC1918 Private Subnets"
  type = "address-group"

  members = [
    "192.168.0.0/16",
    "10.0.0.0/8",
    "172.16.0.0/12"
  ]
}

resource "unifi_firewall_group" "storage_hosts" {
  name = "Storage Hosts"
  type = "address-group"

  members = [
    "VLAN 1 [Management]",
    "VLAN 1 [Management]",
    "VLAN 1 (Management)",
    "VLAN 10 (SecOps)",
    "VLAN 10 (SecOps)"
  ]
}

resource "unifi_firewall_group" "dns_resolvers" {
  name = "DNS Resolvers"
  type = "address-group"

  members = [
    "VLAN 1 [Secondary DNS]",
    "VLAN 1 (Management)",
    "VLAN 110 (Services)",
    "VLAN 110 (Services)"
  ]
}

resource "unifi_firewall_group" "storage_shares_ports" {
  name = "Storage Shares Ports"
  type = "port-group"

  members = [
    "445",
    "139",
    "2049"
  ]
}

resource "unifi_firewall_group" "dns_ports" {
  name = "DNS Ports"
  type = "port-group"

  members = [
    "53"
  ]
}
