output "vm_name" {
  description = "Name of the Hyper-V VM."
  value       = hyperv_machine_instance.debian.name
}

output "vm_id" {
  description = "Internal Hyper-V VM ID (GUID)."
  value       = hyperv_machine_instance.debian.id
}

output "vhdx_path" {
  description = "Path to the primary VHDX disk."
  value       = hyperv_vhd.debian_disk.path
}
