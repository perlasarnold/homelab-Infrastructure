#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Step 2: Download Debian 13 (Trixie) amd64 netinstall ISO.
.PARAMETER Force
    Skip the re-download prompt if the ISO already exists.
.NOTES
    The ISO is saved to C:\ISOs\ which is the default path expected by terraform\main.tf.
    Verifies the SHA512 checksum after download.
#>
param(
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$isoDir      = "C:\ISOs"
$isoFile     = "$isoDir\debian-13-amd64-netinst.iso"
$isoUrl      = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.4.0-amd64-netinst.iso"
$checksumUrl = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/SHA512SUMS"

Write-Host "[1/3] Ensuring ISO directory exists: $isoDir" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $isoDir | Out-Null

if (Test-Path $isoFile) {
    if ($Force) {
        Write-Host "  ISO already exists at $isoFile — skipping (use -Force to re-download)." -ForegroundColor Yellow
        exit 0
    }
    $redownload = Read-Host "  Re-download? (y/N)"
    if ($redownload -ne "y") {
        Write-Host "  Skipping download." -ForegroundColor Green
        exit 0
    }
}

Write-Host "[2/3] Downloading Debian 13 (Trixie) netinstall ISO (~700 MB)..." -ForegroundColor Cyan
Write-Host "  URL: $isoUrl"
$wc = New-Object System.Net.WebClient
$wc.DownloadFile($isoUrl, $isoFile)
Write-Host "  Download complete: $isoFile" -ForegroundColor Green

Write-Host "[3/3] Verifying SHA512 checksum..." -ForegroundColor Cyan
$checksumFile = "$env:TEMP\debian_SHA512SUMS"
$wc.DownloadFile($checksumUrl, $checksumFile)

$expectedLine = (Get-Content $checksumFile) | Where-Object { $_ -match "debian-13.*netinst.iso$" } | Select-Object -First 1
if (-not $expectedLine) {
    Write-Warning "Could not find checksum in SUMS file — skipping verification."
} else {
    $expectedHash = ($expectedLine -split "\s+")[0].ToUpper()
    $actualHash   = (Get-FileHash -Path $isoFile -Algorithm SHA512).Hash.ToUpper()

    if ($actualHash -eq $expectedHash) {
        Write-Host "  ✅ Checksum verified OK." -ForegroundColor Green
    } else {
        Write-Host "  ❌ Checksum MISMATCH! Delete $isoFile and retry." -ForegroundColor Red
        Remove-Item $isoFile -Force
        exit 1
    }
}

Write-Host "`n✅ Debian 13 (Trixie) ISO ready at: $isoFile" -ForegroundColor Green
Write-Host "   Update terraform\terraform.tfvars if you chose a different path." -ForegroundColor Gray
