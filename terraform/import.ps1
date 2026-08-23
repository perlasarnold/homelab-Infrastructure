#!/usr/bin/env pwsh
###############################################################################
# import.ps1 — Import existing Proxmox resources into Terraform state
#
# Refactored for Multi-Node / Modular structure on 2026-05-14
###############################################################################

param(
    [ValidateSet("proxmox", "unraid", "all")]
    [string]$Module = "proxmox"
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Import-Proxmox {
    Write-Host "`n=== Importing Proxmox Resources ===" -ForegroundColor Cyan
    Set-Location "$ScriptDir\proxmox"
    terraform init -upgrade

    # --- LXC Containers (Modular format) ---
    $lxcImports = @(
        @{ Resource = "module.wireguard.proxmox_virtual_environment_container.this";          Id = "Bulakan/101" },
        @{ Resource = "module.prowlarr.proxmox_virtual_environment_container.this";           Id = "Bulakan/103" },
        @{ Resource = "module.plex.proxmox_virtual_environment_container.this";               Id = "Bulakan/104" },
        @{ Resource = "module.radarr.proxmox_virtual_environment_container.this";             Id = "Bulakan/105" },
        @{ Resource = "module.sonarr.proxmox_virtual_environment_container.this";             Id = "Bulakan/106" },
        @{ Resource = "module.bazarr.proxmox_virtual_environment_container.this";             Id = "Bulakan/107" },
        @{ Resource = "module.jackett.proxmox_virtual_environment_container.this";            Id = "Bulakan/108" },
        @{ Resource = "module.audiobookshelf.proxmox_virtual_environment_container.this";     Id = "Bulakan/109" },
        @{ Resource = "module.photoprism.proxmox_virtual_environment_container.this";         Id = "Bulakan/111" },
        @{ Resource = "module.transmission.proxmox_virtual_environment_container.this";       Id = "Bulakan/112" },
        @{ Resource = "module.heimdall_dashboard.proxmox_virtual_environment_container.this"; Id = "Bulakan/115" },
        @{ Resource = "module.jellyfin.proxmox_virtual_environment_container.this";           Id = "Bulakan/116" },
        @{ Resource = "module.pihole.proxmox_virtual_environment_container.this";             Id = "Bulakan/301" },
        @{ Resource = "module.cloudflared.proxmox_virtual_environment_container.this";        Id = "Bulakan/304" },
        @{ Resource = "module.netbootxyz.proxmox_virtual_environment_container.this";         Id = "Bulakan/118" },
        @{ Resource = "module.qbittorrent.proxmox_virtual_environment_container.this";        Id = "Bulakan/100" },
        @{ Resource = "module.nginxproxymanager.proxmox_virtual_environment_container.this";  Id = "Bulakan/102" },
        @{ Resource = "module.booklore.proxmox_virtual_environment_container.this";           Id = "Bulakan/117" },
        @{ Resource = "module.openwrt.proxmox_virtual_environment_container.this";            Id = "Bulakan/302" }
    )

    foreach ($item in $lxcImports) {
        Write-Host "  Importing $($item.Resource) ..." -ForegroundColor Yellow
        terraform import $item.Resource $item.Id
    }

    # --- Virtual Machines ---
    $vmImports = @(
        @{ Resource = "proxmox_virtual_environment_vm.perlas_w10";    Id = "Bulakan/201" },
        @{ Resource = "proxmox_virtual_environment_vm.immich_ubuntu";  Id = "Bulakan/204" },
        @{ Resource = "proxmox_virtual_environment_vm.w11e";           Id = "Bulakan/202" },
        @{ Resource = "proxmox_virtual_environment_vm.bastion";        Id = "Bulakan/203" },
        @{ Resource = "proxmox_virtual_environment_vm.hack_sonoma";    Id = "Bulakan/305" }
    )

    foreach ($item in $vmImports) {
        Write-Host "  Importing $($item.Resource) ..." -ForegroundColor Yellow
        terraform import $item.Resource $item.Id
    }

    Write-Host "`nProxmox import complete. Run 'terraform plan' to review drift." -ForegroundColor Green
}

function Import-Unraid {
    Write-Warning "Unraid (Mercado) is reported CRASHED. Skipping import."
}

# --- Entry point ---
switch ($Module) {
    "proxmox" { Import-Proxmox }
    "unraid"  { Import-Unraid }
    "all"     { Import-Proxmox; Import-Unraid }
}

Write-Host "`nDone! Next steps:" -ForegroundColor Cyan
Write-Host "  cd terraform\proxmox && terraform plan"
