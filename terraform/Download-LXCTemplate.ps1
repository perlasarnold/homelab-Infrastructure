#!/usr/bin/env pwsh
###############################################################################
# Download-LXCTemplate.ps1 — Download LXC templates to Proxmox
#
# Must be run from a machine with SSH access to the Proxmox node
###############################################################################

param(
    [string]$ProxmoxHost = "VLAN 1 [MGMT]",
    [string]$TemplateName = "debian-12-standard"
)

Write-Host "=== Downloading LXC Template ===" -ForegroundColor Cyan
Write-Host "Target: $ProxmoxHost"

$sshCommand = @"
pveam update
pveam available | grep -i 'debian-12-standard'
pveam download local $TemplateName
ls -la /var/lib/vz/template/cache/
"@

Write-Host "Connecting to $ProxmoxHost..." -ForegroundColor Yellow
ssh "root@$ProxmoxHost" $sshCommand

Write-Host "`nTemplate download complete. Verify with:" -ForegroundColor Green
Write-Host "  ssh root@$ProxmoxHost 'ls -la /var/lib/vz/template/cache/'"
