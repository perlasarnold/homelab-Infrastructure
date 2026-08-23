#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Step 1: Enable Hyper-V and configure WinRM HTTPS for the rgl/hyperv Terraform provider.
.DESCRIPTION
    - Enables the Hyper-V Windows feature (prompts for reboot if needed)
    - Creates a self-signed TLS certificate for WinRM HTTPS (port 5986)
    - Configures WinRM to accept HTTPS connections
    - Opens the firewall for port 5986
    - Exports the certificate for use by Terraform (WINRM_CACERT secret)
.NOTES
    Run as Administrator. May require a reboot after enabling Hyper-V.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ─── 1. Enable Hyper-V ───────────────────────────────────────────────────────
Write-Host "`n[1/5] Checking Hyper-V feature..." -ForegroundColor Cyan

$feature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All
if ($feature.State -ne "Enabled") {
    Write-Host "  Enabling Hyper-V (a reboot may be required)..." -ForegroundColor Yellow
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -NoRestart
    Write-Host "  Hyper-V enabled. PLEASE REBOOT and re-run this script." -ForegroundColor Red
    exit 0
} else {
    Write-Host "  Hyper-V is already enabled." -ForegroundColor Green
}

# ─── 2. Enable WinRM service ─────────────────────────────────────────────────
Write-Host "`n[2/5] Enabling WinRM service..." -ForegroundColor Cyan
Enable-PSRemoting -Force -SkipNetworkProfileCheck | Out-Null
Set-Service -Name WinRM -StartupType Automatic
Start-Service -Name WinRM
Write-Host "  WinRM service is running." -ForegroundColor Green

# ─── 3. Create self-signed cert for WinRM HTTPS ──────────────────────────────
Write-Host "`n[3/5] Creating self-signed TLS certificate for WinRM HTTPS..." -ForegroundColor Cyan

# Ensure the certificate provider is available in non-interactive PowerShell sessions.
Import-Module Microsoft.PowerShell.Security -ErrorAction SilentlyContinue
if (-not (Get-PSDrive -Name Cert -ErrorAction SilentlyContinue)) {
    New-PSDrive -Name Cert -PSProvider Certificate -Root "\" | Out-Null
}

$certSubject = "CN=$env:COMPUTERNAME"
$certPath    = "Microsoft.PowerShell.Security\Certificate::LocalMachine\My"
$certFile    = "$PSScriptRoot\winrm_cacert.pem"

# Remove old WinRM HTTPS listener if present
$existing = Get-WSManInstance winrm/config/listener -Enumerate |
            Where-Object { $_.Transport -eq "HTTPS" }
if ($existing) {
    Write-Host "  Removing existing HTTPS listener..." -ForegroundColor Yellow
    Remove-WSManInstance winrm/config/listener -SelectorSet @{Address="*"; Transport="HTTPS"}
}

# Create new cert (2-year validity)
$cert = New-SelfSignedCertificate `
    -Subject      $certSubject `
    -CertStoreLocation $certPath `
    -KeyUsage     DigitalSignature, KeyEncipherment `
    -KeyAlgorithm RSA `
    -KeyLength    2048 `
    -NotAfter     (Get-Date).AddYears(2) `
    -FriendlyName "WinRM HTTPS (Terraform Hyper-V)"

Write-Host "  Certificate created: Thumbprint = $($cert.Thumbprint)" -ForegroundColor Green

# ─── 4. Create WinRM HTTPS listener ──────────────────────────────────────────
Write-Host "`n[4/5] Creating WinRM HTTPS listener on port 5986..." -ForegroundColor Cyan

New-WSManInstance winrm/config/listener `
    -SelectorSet @{Address="*"; Transport="HTTPS"} `
    -ValueSet    @{Hostname=$env:COMPUTERNAME; CertificateThumbprint=$cert.Thumbprint} | Out-Null

# Allow unencrypted? No — keep it HTTPS only.
Set-WSManInstance -ResourceURI winrm/config/service `
    -ValueSet @{AllowUnencrypted="false"} | Out-Null

Set-WSManInstance -ResourceURI winrm/config/service/auth `
    -ValueSet @{Basic="true"} | Out-Null

Write-Host "  WinRM HTTPS listener created." -ForegroundColor Green

# ─── 5. Firewall rule ─────────────────────────────────────────────────────────
Write-Host "`n[5/5] Opening firewall port 5986 (WinRM HTTPS)..." -ForegroundColor Cyan

$ruleName = "WinRM HTTPS - Terraform Hyper-V"
if (-not (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule `
        -DisplayName $ruleName `
        -Direction   Inbound `
        -Protocol    TCP `
        -LocalPort   5986 `
        -Action      Allow | Out-Null
    Write-Host "  Firewall rule created." -ForegroundColor Green
} else {
    Write-Host "  Firewall rule already exists." -ForegroundColor Green
}

# ─── Export cert as PEM for Terraform / GitHub Secrets ───────────────────────
Write-Host "`nExporting certificate to PEM for Terraform..." -ForegroundColor Cyan

$certBytes = $cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
$b64       = [System.Convert]::ToBase64String($certBytes, [System.Base64FormattingOptions]::InsertLineBreaks)
$pem       = "-----BEGIN CERTIFICATE-----`n$b64`n-----END CERTIFICATE-----"
Set-Content -Path $certFile -Value $pem -Encoding ASCII

Write-Host "  Certificate exported to: $certFile" -ForegroundColor Green
Write-Host "  Base64 for WINRM_CACERT GitHub secret:" -ForegroundColor Yellow
Write-Host "  $([Convert]::ToBase64String([System.IO.File]::ReadAllBytes($certFile)))" -ForegroundColor DarkYellow

Write-Host "`n✅ WinRM HTTPS setup complete!" -ForegroundColor Green
Write-Host "   Test with: winrm enumerate winrm/config/listener" -ForegroundColor Gray
Write-Host "   Terraform provider will connect to: https://localhost:5986" -ForegroundColor Gray
