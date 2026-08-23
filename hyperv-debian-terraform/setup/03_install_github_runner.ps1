#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Step 3: Install and register a self-hosted GitHub Actions runner as a Windows service.
.DESCRIPTION
    Downloads the latest GitHub Actions runner, registers it with your repository,
    and installs it as a Windows service so it starts automatically.
.PARAMETER RepoUrl
    Full HTTPS URL of your GitHub repository.
    Example: https://github.com/YOUR-USERNAME/hyperv-debian-terraform
.PARAMETER Token
    Registration token from:
    https://github.com/YOUR-USERNAME/hyperv-debian-terraform/settings/actions/runners/new
    (Click "New self-hosted runner" → copy the token shown)
.EXAMPLE
    .\03_install_github_runner.ps1 `
        -RepoUrl "https://github.com/myuser/hyperv-debian-terraform" `
        -Token   "AXXXXXXXXXXXXXXXXXXXXXXXXXX"
#>

param(
    [Parameter(Mandatory)][string]$RepoUrl,
    [Parameter(Mandatory)][string]$Token
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$runnerDir     = "C:\actions-runner"
$runnerVersion = "2.325.0"   # Update to latest from https://github.com/actions/runner/releases
$runnerZip     = "$env:TEMP\actions-runner.zip"
$runnerUrl     = "https://github.com/actions/runner/releases/download/v${runnerVersion}/actions-runner-win-x64-${runnerVersion}.zip"

# ─── 1. Create runner directory ───────────────────────────────────────────────
Write-Host "[1/5] Creating runner directory: $runnerDir" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $runnerDir | Out-Null

# ─── 2. Download runner package ───────────────────────────────────────────────
Write-Host "[2/5] Downloading GitHub Actions runner v$runnerVersion..." -ForegroundColor Cyan
Write-Host "  URL: $runnerUrl"

if (-not (Test-Path $runnerZip)) {
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($runnerUrl, $runnerZip)
}
Write-Host "  Downloaded." -ForegroundColor Green

# ─── 3. Extract ──────────────────────────────────────────────────────────────
Write-Host "[3/5] Extracting runner package..." -ForegroundColor Cyan
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($runnerZip, $runnerDir)
Write-Host "  Extracted to $runnerDir" -ForegroundColor Green

# ─── 4. Configure (register with GitHub) ────────────────────────────────────
Write-Host "[4/5] Registering runner with: $RepoUrl" -ForegroundColor Cyan
Push-Location $runnerDir

$runnerName = "$env:COMPUTERNAME-hyperv-runner"
.\config.cmd `
    --url   $RepoUrl `
    --token $Token `
    --name  $runnerName `
    --labels "self-hosted,Windows,hyperv" `
    --runnergroup "Default" `
    --work "_work" `
    --unattended

Pop-Location
Write-Host "  Runner registered as: $runnerName" -ForegroundColor Green

# ─── 5. Install as Windows service ───────────────────────────────────────────
Write-Host "[5/5] Installing runner as Windows service..." -ForegroundColor Cyan
Push-Location $runnerDir
.\svc.cmd install
.\svc.cmd start
Pop-Location

$svc = Get-Service -Name "actions.runner.*" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($svc -and $svc.Status -eq "Running") {
    Write-Host "  ✅ Runner service is running: $($svc.Name)" -ForegroundColor Green
} else {
    Write-Warning "Service may not have started. Check with: Get-Service 'actions.runner.*'"
}

Write-Host "`n✅ Self-hosted runner installed!" -ForegroundColor Green
Write-Host "   Verify at: $RepoUrl/settings/actions/runners" -ForegroundColor Gray
Write-Host "   Runner labels: self-hosted, Windows, hyperv" -ForegroundColor Gray
