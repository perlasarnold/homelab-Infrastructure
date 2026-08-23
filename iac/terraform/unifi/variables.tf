# ------------------------------------------------------------------------------
# UniFi Provider & Foundation Variables
# ------------------------------------------------------------------------------

variable "unifi_api_url" {
  type        = string
  description = "URL of the UniFi Controller / Gateway Max (e.g. https://192.168.1.1:8443)"
  default     = "https://192.168.1.1"
}

variable "unifi_username" {
  type        = string
  description = "Administrator username for UniFi Network API"
  default     = "admin"
  sensitive   = true
}

variable "unifi_password" {
  type        = string
  description = "Administrator password for UniFi Network API"
  sensitive   = true
}

variable "unifi_site" {
  type        = string
  description = "UniFi Site identifier"
  default     = "default"
}

variable "unifi_allow_insecure" {
  type        = bool
  description = "Allow self-signed SSL certificates for UniFi gateway"
  default     = true
}

# Subnet CIDR definitions for Class C foundation
variable "vlan_mgmt_cidr" {
  type        = string
  default     = "192.168.10.1/24"
  description = "VLAN 10 MGMT Gateway IP and Subnet"
}

variable "vlan_trusted_cidr" {
  type        = string
  default     = "192.168.20.1/24"
  description = "VLAN 20 TRUSTED Gateway IP and Subnet"
}

variable "vlan_iot_cidr" {
  type        = string
  default     = "192.168.30.1/24"
  description = "VLAN 30 IOT Gateway IP and Subnet"
}

variable "vlan_services_cidr" {
  type        = string
  default     = "192.168.110.1/24"
  description = "VLAN 110 SERVICES Gateway IP and Subnet"
}

variable "vlan_dmz_cidr" {
  type        = string
  default     = "192.168.120.1/24"
  description = "VLAN 120 DMZ Gateway IP and Subnet"
}
