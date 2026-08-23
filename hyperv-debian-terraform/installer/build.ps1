<#
.SYNOPSIS
    Build installer.py into a standalone Windows .exe using PyInstaller.
    Run this once locally — commit the .exe or attach to a GitHub Release.
.NOTES
    Requires Python 3.11+ and pip available.
    Output: dist/Homelab-Installer.exe  (~15-20 MB, no Python install needed on target)
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = $PSScriptRoot

Write-Host "[1/4] Installing Python dependencies..." -ForegroundColor Cyan
pip install -r "$scriptDir/requirements.txt" --quiet

Write-Host "[2/4] Running PyInstaller..." -ForegroundColor Cyan
pyinstaller `
    --onefile `
    --console `
    --name "Homelab-Installer" `
    --icon NONE `
    --hidden-import rich `
    --hidden-import InquirerPy `
    --hidden-import prompt_toolkit `
    "$scriptDir/installer.py"

Write-Host "[3/4] Cleaning up build artifacts..." -ForegroundColor Cyan
Remove-Item -Recurse -Force "$scriptDir/build" -ErrorAction SilentlyContinue
Remove-Item -Force "$scriptDir/Homelab-Installer.spec" -ErrorAction SilentlyContinue

$exe = "$scriptDir/dist/Homelab-Installer.exe"
if (Test-Path $exe) {
    $sizeMB = [Math]::Round((Get-Item $exe).Length / 1MB, 1)
    Write-Host "[4/4] Done! Executable: $exe ($sizeMB MB)" -ForegroundColor Green
    Write-Host ""
    Write-Host "To distribute:" -ForegroundColor Yellow
    Write-Host "  - Attach dist/Homelab-Installer.exe to a GitHub Release"
    Write-Host "  - Or place it in the repo root for direct download"
    Write-Host "  - Users run it as Administrator — no other installs required"
} else {
    Write-Host "Build failed — check PyInstaller output above." -ForegroundColor Red
    exit 1
}
