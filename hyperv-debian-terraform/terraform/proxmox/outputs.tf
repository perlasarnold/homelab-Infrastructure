output "vm_id" {
  description = "Proxmox VM ID."
  value       = proxmox_virtual_environment_vm.debian.vm_id
}

output "vm_name" {
  description = "VM display name."
  value       = proxmox_virtual_environment_vm.debian.name
}

output "vm_ipv4_address" {
  description = "VM IPv4 address (after guest agent reports it)."
  value       = try(proxmox_virtual_environment_vm.debian.ipv4_addresses[1][0], "pending — VM booting")
}

output "vm_node" {
  description = "Proxmox node hosting this VM."
  value       = proxmox_virtual_environment_vm.debian.node_name
}
