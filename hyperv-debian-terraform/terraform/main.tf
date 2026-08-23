terraform {
  required_version = ">= 1.5.0"

  required_providers {
    hyperv = {
      source  = "rgl/hyperv"
      version = "~> 1.0"
    }
  }
}

# ─── Provider: connects to local Hyper-V via WinRM HTTPS ─────────────────────
# Credentials are read from environment variables at runtime:
#   TF_VAR_winrm_username  /  TF_VAR_winrm_password
# The cacert file path points to the PEM exported by 01_enable_hyperv_winrm.ps1
provider "hyperv" {
  user     = var.winrm_username
  password = var.winrm_password
  host     = "localhost"
  port     = 5986
  https    = true
  insecure = false             # strict cert check — use cacert_path
  cacert_path = var.winrm_cacert_path
  timeout  = "30s"
}

# ─── Virtual Hard Disk ────────────────────────────────────────────────────────
resource "hyperv_vhd" "debian_disk" {
  path              = "${var.vhdx_dir}\\${var.vm_name}\\${var.vm_name}.vhdx"
  size              = var.disk_size_gb * 1024 * 1024 * 1024   # bytes
  block_size        = 1048576                                   # 1 MiB
  logical_sector_size = 512
  physical_sector_size = 512
  vhd_type          = "Dynamic"
}

# ─── VM Instance ──────────────────────────────────────────────────────────────
resource "hyperv_machine_instance" "debian" {
  name                   = var.vm_name
  generation             = 2
  processor_count        = var.vm_cpus
  static_memory          = false
  dynamic_memory_minimum_bytes = 512 * 1024 * 1024   # 512 MB
  dynamic_memory_maximum_bytes = var.vm_memory_mb * 1024 * 1024
  memory_startup_bytes   = var.vm_memory_mb * 1024 * 1024

  # Secure Boot — must be disabled for Debian (or use MicrosoftUEFICertificateAuthority template)
  secure_boot_enabled    = true
  secure_boot_template   = "MicrosoftUEFICertificateAuthority"

  # Disable checkpoints for IaC purity
  checkpoint_type        = "Disabled"

  automatic_start_action = "Nothing"
  automatic_stop_action  = "ShutDown"

  # ── Network adapters ────────────────────────────────────────────────────────
  network_adaptors {
    name        = "eth0"
    switch_name = var.network_switch
    wait_for_ips_timeout = 0
  }

  # ── DVD drive (boot installer) ───────────────────────────────────────────────
  dvd_drives {
    controller_number   = 0
    controller_location = 1
    path                = var.iso_path
  }

  # ── VHDX data drive ──────────────────────────────────────────────────────────
  hard_disk_drives {
    controller_type     = "SCSI"
    controller_number   = 0
    controller_location = 0
    path                = hyperv_vhd.debian_disk.path
  }

  # ── Boot order: DVD first (for initial install), then VHDX ──────────────────
  vm_firmware {
    enable_secure_boot = true
    secure_boot_template = "MicrosoftUEFICertificateAuthority"

    boot_order {
      boot_type           = "DvdDrive"
      controller_number   = 0
      controller_location = 1
    }

    boot_order {
      boot_type            = "HardDiskDrive"
      controller_type      = "SCSI"
      controller_number    = 0
      controller_location  = 0
    }
  }

  # Ensure the VHD exists before creating the VM
  depends_on = [hyperv_vhd.debian_disk]
}
