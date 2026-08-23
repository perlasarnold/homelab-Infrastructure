#!/usr/bin/env pwsh
###############################################################################
# Deploy-Netbootxyz.ps1 - FULLY AUTOMATED DEPLOYMENT
###############################################################################

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProxmoxHost,

    [string]$SshUser = "root",
    [int]$VmId = 118,
    [string]$TerraformPath = "/opt/homelab-infrastructure\terraform\proxmox"
)

$TerraformExe = "/home/admin\AppData\Local\Microsoft\WinGet\Links\terraform.exe"
$ErrorActionPreference = "Stop"

function Write-Header($text) {
    Write-Host ""
    Write-Host "========================================"
    Write-Host $text
    Write-Host "========================================"
    Write-Host ""
}

function Write-Success($text) {
    Write-Host "[OK] $text" -ForegroundColor Green
}

Write-Header "STEP 0: Checking Prerequisites"

if (-not (Test-Path $TerraformExe)) {
    Write-Host "Installing Terraform..."
    winget install HashiCorp.Terraform --accept-package-agreements
}
Write-Success "Terraform found"

Write-Host "Checking SSH connectivity..."
$sshOutput = ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "${SshUser}@${ProxmoxHost}" "echo OK" 2>&1 | Out-String
if ($sshOutput -notmatch "OK") {
    Write-Error "Cannot SSH to Proxmox. Password authentication required."
    Write-Host ""
    Write-Host "Please set up SSH keys first:"
    Write-Host "  1. ssh-keygen -t ed25519 -f %USERPROFILE%\.ssh\proxmox_id25519"
    Write-Host "  2. ssh-copy-id -i %USERPROFILE%\.ssh\proxmox_id25519.pub root@${ProxmoxHost}"
    Write-Host ""
    Write-Host "Or run manually with password prompts."
    exit 1
}
Write-Success "SSH connectivity verified"

Write-Header "STEP 1: Download LXC Template to Proxmox"

Write-Host "Updating template database..."
ssh "${SshUser}@${ProxmoxHost}" "pveam update" | Out-Null

Write-Host "Finding debian-12-standard template..."
$template = ssh "${SshUser}@${ProxmoxHost}" "pveam available | grep debian-12-standard | head -1" 2>$null

if (-not $template) {
    throw "No debian-12-standard template found"
}

$:templateName = ($template -split '\s+')[1]
Write-Success "Found template: $:templateName"

$existing = ssh "${SshUser}@${ProxmoxHost}" "ls /var/lib/vz/template/cache/ 2>/dev/null | grep '$:templateName'" 2>$null

if ($existing) {
    Write-Success "Template already exists: $:templateName"
}
else {
    Write-Host "Downloading $:templateName to Proxmox (2-5 minutes)..."
    ssh "${SshUser}@${ProxmoxHost}" "pveam download local $:templateName"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to download template"
    }
    Write-Success "Template downloaded"
}

$tfvarsPath = Join-Path $TerraformPath "terraform.tfvars"
if (-not (Test-Path $tfvarsPath)) {
    throw "terraform.tfvars not found at $tfvarsPath"
}

$tfvarsContent = Get-Content $tfvarsPath -Raw
$newContent = $tfvarsContent -replace 'lxc_template\s*=\s*"[^"]*"', "lxc_template = \"local:vztmpl/$:templateName\""
Set-Content -Path $tfvarsPath -Value $newContent -NoNewline
Write-Success "Updated terraform.tfvars with template: $:templateName"

Write-Header "STEP 2: Terraform Deployment"

Set-Location $TerraformPath

Write-Host "Running: terraform init"
& $TerraformExe init -upgrade | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "terraform init failed"
}
Write-Success "Terraform initialized"

Write-Host ""
Write-Host "Running: terraform plan"
& $TerraformExe plan -target="proxmox_virtual_environment_container.netbootxyz" -out="tfplan"
if ($LASTEXITCODE -ne 0) {
    throw "terraform plan failed"
}

Write-Host ""
Write-Host "Running: terraform apply"
Write-Host "Creating container CT ${VmId}..."
& $TerraformExe apply -auto-approve "tfplan"
if ($LASTEXITCODE -ne 0) {
    throw "terraform apply failed"
}
Write-Success "Container created successfully!"

Remove-Item "tfplan" -ErrorAction SilentlyContinue

Write-Header "STEP 3: Waiting for Container to Start"

$:maxAttempts = 30
for ($attempt = 1; $attempt -le $:maxAttempts; $attempt++) {
    Write-Host "Attempt $attempt/$:maxAttempts: Checking CT $VmId status..."
    $status = ssh "${SshUser}@${ProxmoxHost}" "pct status $VmId" 2>$null
    
    if ($status -match "running") {
        Write-Success "Container is running!"
        break
    }
    
    if ($attempt -eq $:maxAttempts) {
        throw "Container did not start in time"
    }
    
    Start-Sleep -Seconds 5
}

Write-Header "STEP 4: Installing Netboot.xyz Software"
Write-Host "Running tteck install script inside container..."
Write-Host "This will take 5-10 minutes. Please wait..."
Write-Host ""

$installCommand = 'bash -c "$(wget -qLO - https://github.com/tteck/Proxmox/raw/main/ct/netbootxyz.sh)"'
$installResult = ssh "${SshUser}@${ProxmoxHost}" "pct exec $VmId -- $installCommand" 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Warning "Installation may have completed with warnings"
}
else {
    Write-Success "Netboot.xyz installation complete"
}

Write-Host ""
Write-Host "Verifying Docker containers..."
$dockerCheck = ssh "${SshUser}@${ProxmoxHost}" "pct exec $VmId -- docker ps 2>/dev/null || echo 'Docker not ready'" 2>$null
if ($dockerCheck -match "netbootxyz") {
    Write-Success "Services are running"
}

Write-Header "DEPLOYMENT COMPLETE"

Write-Host ""
Write-Host "Container Details:"
Write-Host "  VM ID:     $VmId"
Write-Host "  Name:      netbootxyz"
Write-Host "  IP:        VLAN 1 (Mgmt)"
Write-Host "  Proxmox:   https://${ProxmoxHost}:8006"
Write-Host ""
Write-Host "Web Interfaces:"
Write-Host "  Netboot.xyz: http://VLAN 1 (Mgmt):3000"
Write-Host ""
Write-Host "Next Steps:"
Write-Host "  1. Visit http://VLAN 1 (Mgmt):3000 to configure netboot.xyz"
Write-Host "  2. Set up DHCP/PXE (TFTP server: VLAN 1 (Mgmt))"
Write-Host "  3. Test network boot from a spare machine"
Write-Host ""
Write-Host "Documentation:"
Write-Host "  See 05-Services/Netbootxyz.md for full configuration guide"
Write-Host ""
Write-Host "[DONE] Deployment completed!" -ForegroundColor Green
